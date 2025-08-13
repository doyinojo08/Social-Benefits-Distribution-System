;; Social Benefits Distribution - Benefits Registry Contract
;; Manages benefit programs, funding, and program lifecycle

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROGRAM-NOT-FOUND (err u101))
(define-constant ERR-PROGRAM-INACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-INPUT (err u104))

;; Data Variables
(define-data-var next-program-id uint u1)
(define-data-var total-programs uint u0)

;; Data Maps
(define-map programs
  { program-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    total-budget: uint,
    allocated-funds: uint,
    remaining-funds: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    program-type: (string-ascii 50),
    administrator: principal,
    created-at: uint
  }
)

(define-map program-administrators
  { program-id: uint, admin: principal }
  { authorized: bool }
)

(define-map program-statistics
  { program-id: uint }
  {
    total-recipients: uint,
    total-payments: uint,
    average-payment: uint,
    last-payment-block: uint
  }
)

;; Public Functions

;; Create a new benefit program
(define-public (create-program
  (name (string-ascii 100))
  (description (string-ascii 500))
  (total-budget uint)
  (duration-blocks uint)
  (program-type (string-ascii 50)))
  (let ((program-id (var-get next-program-id))
        (current-block block-height))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> total-budget u0) ERR-INVALID-INPUT)
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)

    (map-set programs
      { program-id: program-id }
      {
        name: name,
        description: description,
        total-budget: total-budget,
        allocated-funds: u0,
        remaining-funds: total-budget,
        start-block: current-block,
        end-block: (+ current-block duration-blocks),
        is-active: true,
        program-type: program-type,
        administrator: tx-sender,
        created-at: current-block
      }
    )

    (map-set program-administrators
      { program-id: program-id, admin: tx-sender }
      { authorized: true }
    )

    (map-set program-statistics
      { program-id: program-id }
      {
        total-recipients: u0,
        total-payments: u0,
        average-payment: u0,
        last-payment-block: u0
      }
    )

    (var-set next-program-id (+ program-id u1))
    (var-set total-programs (+ (var-get total-programs) u1))

    (ok program-id)
  )
)

;; Add funds to a program
(define-public (add-program-funds (program-id uint) (amount uint))
  (let ((program (unwrap! (map-get? programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND)))
    (asserts! (get is-active program) ERR-PROGRAM-INACTIVE)
    (asserts! (is-program-admin program-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    (map-set programs
      { program-id: program-id }
      (merge program {
        total-budget: (+ (get total-budget program) amount),
        remaining-funds: (+ (get remaining-funds program) amount)
      })
    )

    (ok true)
  )
)

;; Allocate funds for payment
(define-public (allocate-funds (program-id uint) (amount uint))
  (let ((program (unwrap! (map-get? programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND)))
    (asserts! (get is-active program) ERR-PROGRAM-INACTIVE)
    (asserts! (>= (get remaining-funds program) amount) ERR-INSUFFICIENT-FUNDS)

    (map-set programs
      { program-id: program-id }
      (merge program {
        allocated-funds: (+ (get allocated-funds program) amount),
        remaining-funds: (- (get remaining-funds program) amount)
      })
    )

    (ok true)
  )
)

;; Update program status
(define-public (update-program-status (program-id uint) (is-active bool))
  (let ((program (unwrap! (map-get? programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND)))
    (asserts! (is-program-admin program-id tx-sender) ERR-NOT-AUTHORIZED)

    (map-set programs
      { program-id: program-id }
      (merge program { is-active: is-active })
    )

    (ok true)
  )
)

;; Add program administrator
(define-public (add-program-admin (program-id uint) (admin principal))
  (begin
    (asserts! (is-program-admin program-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? programs { program-id: program-id })) ERR-PROGRAM-NOT-FOUND)

    (map-set program-administrators
      { program-id: program-id, admin: admin }
      { authorized: true }
    )

    (ok true)
  )
)

;; Update program statistics
(define-public (update-program-stats
  (program-id uint)
  (recipients-increment uint)
  (payment-amount uint))
  (let ((stats (default-to
                 { total-recipients: u0, total-payments: u0, average-payment: u0, last-payment-block: u0 }
                 (map-get? program-statistics { program-id: program-id }))))

    (let ((new-total-payments (+ (get total-payments stats) u1))
          (new-total-recipients (+ (get total-recipients stats) recipients-increment))
          (total-amount (+ (* (get average-payment stats) (get total-payments stats)) payment-amount)))

      (map-set program-statistics
        { program-id: program-id }
        {
          total-recipients: new-total-recipients,
          total-payments: new-total-payments,
          average-payment: (/ total-amount new-total-payments),
          last-payment-block: block-height
        }
      )

      (ok true)
    )
  )
)

;; Read-only Functions

;; Get program details
(define-read-only (get-program (program-id uint))
  (map-get? programs { program-id: program-id })
)

;; Get program statistics
(define-read-only (get-program-stats (program-id uint))
  (map-get? program-statistics { program-id: program-id })
)

;; Check if user is program admin
(define-read-only (is-program-admin (program-id uint) (admin principal))
  (default-to false
    (get authorized (map-get? program-administrators { program-id: program-id, admin: admin }))
  )
)

;; Get total number of programs
(define-read-only (get-total-programs)
  (var-get total-programs)
)

;; Check if program is active and within timeframe
(define-read-only (is-program-active (program-id uint))
  (match (map-get? programs { program-id: program-id })
    program (and
              (get is-active program)
              (>= block-height (get start-block program))
              (<= block-height (get end-block program)))
    false
  )
)

;; Get available funds for program
(define-read-only (get-available-funds (program-id uint))
  (match (map-get? programs { program-id: program-id })
    program (get remaining-funds program)
    u0
  )
)
