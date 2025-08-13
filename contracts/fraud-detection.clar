;; Social Benefits Distribution - Fraud Detection Contract
;; Implements fraud prevention mechanisms and suspicious activity monitoring

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-ALERT-NOT-FOUND (err u402))
(define-constant ERR-THRESHOLD-EXCEEDED (err u403))

;; Risk thresholds
(define-constant HIGH-RISK-THRESHOLD u75)
(define-constant MEDIUM-RISK-THRESHOLD u50)
(define-constant MAX-DAILY-PAYMENTS u5)
(define-constant MAX-PAYMENT-AMOUNT u10000)

;; Data Variables
(define-data-var next-alert-id uint u1)
(define-data-var total-alerts uint u0)
(define-data-var fraud-detection-enabled bool true)

;; Data Maps
(define-map fraud-alerts
  { alert-id: uint }
  {
    recipient: principal,
    alert-type: (string-ascii 50),
    risk-level: uint,
    description: (string-ascii 200),
    created-block: uint,
    status: (string-ascii 20),
    investigated-by: (optional principal),
    resolution: (optional (string-ascii 200))
  }
)

(define-map recipient-activity
  { recipient: principal, date: uint }
  {
    payment-count: uint,
    total-amount: uint,
    last-payment-block: uint,
    suspicious-patterns: uint
  }
)

(define-map duplicate-checks
  { identification: (string-ascii 50) }
  {
    recipients: (list 10 principal),
    flagged: bool,
    last-check: uint
  }
)

(define-map risk-patterns
  { pattern-id: uint }
  {
    pattern-name: (string-ascii 50),
    description: (string-ascii 200),
    risk-weight: uint,
    is-active: bool
  }
)

(define-map investigation-cases
  { case-id: uint }
  {
    recipient: principal,
    investigator: principal,
    case-type: (string-ascii 50),
    status: (string-ascii 20),
    created-block: uint,
    evidence: (string-ascii 500),
    conclusion: (optional (string-ascii 200))
  }
)

;; Public Functions

;; Create fraud alert
(define-public (create-fraud-alert
  (recipient principal)
  (alert-type (string-ascii 50))
  (risk-level uint)
  (description (string-ascii 200)))
  (let ((alert-id (var-get next-alert-id)))
    (asserts! (<= risk-level u100) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set fraud-alerts
      { alert-id: alert-id }
      {
        recipient: recipient,
        alert-type: alert-type,
        risk-level: risk-level,
        description: description,
        created-block: block-height,
        status: "open",
        investigated-by: none,
        resolution: none
      }
    )

    (var-set next-alert-id (+ alert-id u1))
    (var-set total-alerts (+ (var-get total-alerts) u1))

    (ok alert-id)
  )
)

;; Check for duplicate recipients
(define-public (check-duplicate-recipients (identification (string-ascii 50)) (recipient principal))
  (let ((existing (default-to
                    { recipients: (list), flagged: false, last-check: u0 }
                    (map-get? duplicate-checks { identification: identification }))))

    (let ((updated-recipients (unwrap! (as-max-len? (append (get recipients existing) recipient) u10) ERR-INVALID-INPUT)))
      (map-set duplicate-checks
        { identification: identification }
        {
          recipients: updated-recipients,
          flagged: (> (len updated-recipients) u1),
          last-check: block-height
        }
      )

      ;; Create alert if duplicates found
      (if (> (len updated-recipients) u1)
        (create-fraud-alert recipient "duplicate-identity" u80 "Multiple recipients with same identification")
        (ok u0))
    )
  )
)

;; Monitor payment patterns
(define-public (monitor-payment-activity
  (recipient principal)
  (payment-amount uint))
  (let ((today (/ block-height u144)) ;; Approximate daily blocks
        (activity (default-to
                    { payment-count: u0, total-amount: u0, last-payment-block: u0, suspicious-patterns: u0 }
                    (map-get? recipient-activity { recipient: recipient, date: today }))))

    (let ((new-count (+ (get payment-count activity) u1))
          (new-total (+ (get total-amount activity) payment-amount)))

      ;; Update activity
      (map-set recipient-activity
        { recipient: recipient, date: today }
        {
          payment-count: new-count,
          total-amount: new-total,
          last-payment-block: block-height,
          suspicious-patterns: (get suspicious-patterns activity)
        }
      )

      ;; Check for suspicious patterns
      (if (or (> new-count MAX-DAILY-PAYMENTS) (> payment-amount MAX-PAYMENT-AMOUNT))
        (create-fraud-alert recipient "unusual-activity" u70 "Unusual payment pattern detected")
        (ok u0))
    )
  )
)

;; Calculate risk score
(define-public (calculate-risk-score (recipient principal))
  (let ((base-score u0)
        (today (/ block-height u144)))

    ;; Check recent activity
    (let ((activity (map-get? recipient-activity { recipient: recipient, date: today })))
      (let ((activity-score (match activity
                              act (if (> (get payment-count act) MAX-DAILY-PAYMENTS) u30 u0)
                              u0)))

        ;; Check for duplicate identity
        (let ((duplicate-score u0)) ;; Would check duplicate-checks in real implementation

          ;; Check for open alerts
          (let ((alert-score u0)) ;; Would check open alerts in real implementation

            (let ((total-score (+ base-score (+ activity-score (+ duplicate-score alert-score)))))
              (ok (if (> total-score u100) u100 total-score))
            )
          )
        )
      )
    )
  )
)

;; Investigate fraud alert
(define-public (investigate-alert
  (alert-id uint)
  (resolution (string-ascii 200)))
  (let ((alert (unwrap! (map-get? fraud-alerts { alert-id: alert-id }) ERR-ALERT-NOT-FOUND)))
    (asserts! (is-eq (get status alert) "open") ERR-INVALID-INPUT)

    (map-set fraud-alerts
      { alert-id: alert-id }
      (merge alert {
        status: "investigated",
        investigated-by: (some tx-sender),
        resolution: (some resolution)
      })
    )

    (ok true)
  )
)

;; Create investigation case
(define-public (create-investigation-case
  (recipient principal)
  (case-type (string-ascii 50))
  (evidence (string-ascii 500)))
  (let ((case-id (var-get next-alert-id))) ;; Reusing alert ID counter

    (map-set investigation-cases
      { case-id: case-id }
      {
        recipient: recipient,
        investigator: tx-sender,
        case-type: case-type,
        status: "open",
        created-block: block-height,
        evidence: evidence,
        conclusion: none
      }
    )

    (var-set next-alert-id (+ case-id u1))

    (ok case-id)
  )
)

;; Close investigation case
(define-public (close-investigation-case
  (case-id uint)
  (conclusion (string-ascii 200)))
  (let ((case (unwrap! (map-get? investigation-cases { case-id: case-id }) ERR-ALERT-NOT-FOUND)))
    (asserts! (is-eq (get investigator case) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status case) "open") ERR-INVALID-INPUT)

    (map-set investigation-cases
      { case-id: case-id }
      (merge case {
        status: "closed",
        conclusion: (some conclusion)
      })
    )

    (ok true)
  )
)

;; Add risk pattern
(define-public (add-risk-pattern
  (pattern-name (string-ascii 50))
  (description (string-ascii 200))
  (risk-weight uint))
  (let ((pattern-id (var-get next-alert-id))) ;; Reusing counter
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= risk-weight u100) ERR-INVALID-INPUT)

    (map-set risk-patterns
      { pattern-id: pattern-id }
      {
        pattern-name: pattern-name,
        description: description,
        risk-weight: risk-weight,
        is-active: true
      }
    )

    (var-set next-alert-id (+ pattern-id u1))

    (ok pattern-id)
  )
)

;; Toggle fraud detection
(define-public (toggle-fraud-detection (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fraud-detection-enabled enabled)
    (ok true)
  )
)

;; Read-only Functions

;; Get fraud alert
(define-read-only (get-fraud-alert (alert-id uint))
  (map-get? fraud-alerts { alert-id: alert-id })
)

;; Get recipient activity for date
(define-read-only (get-recipient-activity (recipient principal) (date uint))
  (map-get? recipient-activity { recipient: recipient, date: date })
)

;; Check for duplicates
(define-read-only (get-duplicate-check (identification (string-ascii 50)))
  (map-get? duplicate-checks { identification: identification })
)

;; Get investigation case
(define-read-only (get-investigation-case (case-id uint))
  (map-get? investigation-cases { case-id: case-id })
)

;; Get risk pattern
(define-read-only (get-risk-pattern (pattern-id uint))
  (map-get? risk-patterns { pattern-id: pattern-id })
)

;; Check if recipient is high risk
(define-read-only (is-high-risk-recipient (recipient principal))
  (let ((today (/ block-height u144)))
    (match (map-get? recipient-activity { recipient: recipient, date: today })
      activity (or
                 (> (get payment-count activity) MAX-DAILY-PAYMENTS)
                 (> (get suspicious-patterns activity) u3))
      false
    )
  )
)

;; Get total alerts count
(define-read-only (get-total-alerts)
  (var-get total-alerts)
)

;; Check if fraud detection is enabled
(define-read-only (is-fraud-detection-enabled)
  (var-get fraud-detection-enabled)
)

;; Get open alerts count for recipient
(define-read-only (get-open-alerts-count (recipient principal))
  ;; In a real implementation, this would iterate through alerts
  ;; For now, returning a placeholder
  u0
)
