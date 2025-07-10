;; Algae Prevention Contract
;; Manages water treatment and cleaning procedures for outdoor water features

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-FEATURE-ID (err u201))
(define-constant ERR-TREATMENT-OVERDUE (err u202))
(define-constant ERR-UNSAFE-CHEMICAL-LEVEL (err u203))

;; Data Variables
(define-data-var treatment-fee uint u500000) ;; 0.5 STX in microSTX
(define-data-var max-chemical-ppm uint u50)

;; Data Maps
(define-map water-features
  { feature-id: uint }
  {
    owner: principal,
    last-treatment: uint,
    treatment-interval: uint,
    water-volume: uint,
    ph-level: uint,
    algae-level: (string-ascii 20),
    chemical-ppm: uint
  }
)

(define-map treatment-schedules
  { feature-id: uint, week: uint }
  {
    scheduled-treatments: uint,
    completed-treatments: uint,
    chemical-usage: uint,
    water-quality-score: uint
  }
)

(define-map cleaning-providers
  { provider: principal }
  {
    specialization: (string-ascii 50),
    treatments-completed: uint,
    quality-rating: uint,
    chemical-certified: bool
  }
)

;; Public Functions

;; Register water feature for algae prevention
(define-public (register-water-feature (feature-id uint) (water-volume uint) (treatment-interval uint))
  (begin
    (asserts! (is-none (map-get? water-features { feature-id: feature-id })) ERR-INVALID-FEATURE-ID)
    (map-set water-features
      { feature-id: feature-id }
      {
        owner: tx-sender,
        last-treatment: block-height,
        treatment-interval: treatment-interval,
        water-volume: water-volume,
        ph-level: u70, ;; pH 7.0
        algae-level: "low",
        chemical-ppm: u0
      }
    )
    (ok feature-id)
  )
)

;; Apply algae treatment
(define-public (apply-treatment (feature-id uint) (chemical-amount uint) (treatment-type (string-ascii 50)))
  (let (
    (feature-data (unwrap! (map-get? water-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (provider-data (default-to
      { specialization: "general", treatments-completed: u0, quality-rating: u0, chemical-certified: false }
      (map-get? cleaning-providers { provider: tx-sender })
    ))
  )
    (asserts! (< chemical-amount (var-get max-chemical-ppm)) ERR-UNSAFE-CHEMICAL-LEVEL)

    ;; Update feature treatment record
    (map-set water-features
      { feature-id: feature-id }
      (merge feature-data {
        last-treatment: block-height,
        chemical-ppm: chemical-amount,
        algae-level: "low"
      })
    )

    ;; Update provider stats
    (map-set cleaning-providers
      { provider: tx-sender }
      (merge provider-data {
        treatments-completed: (+ (get treatments-completed provider-data) u1),
        quality-rating: (+ (get quality-rating provider-data) u5)
      })
    )

    (ok true)
  )
)

;; Test water quality
(define-public (test-water-quality (feature-id uint) (ph-reading uint) (algae-reading (string-ascii 20)))
  (let (
    (feature-data (unwrap! (map-get? water-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
  )
    (asserts! (is-eq (get owner feature-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set water-features
      { feature-id: feature-id }
      (merge feature-data {
        ph-level: ph-reading,
        algae-level: algae-reading
      })
    )
    (ok true)
  )
)

;; Schedule weekly cleaning
(define-public (schedule-weekly-cleaning (feature-id uint))
  (let (
    (feature-data (unwrap! (map-get? water-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (current-week (/ block-height u1008)) ;; Approximate blocks per week
    (schedule-data (default-to
      { scheduled-treatments: u0, completed-treatments: u0, chemical-usage: u0, water-quality-score: u0 }
      (map-get? treatment-schedules { feature-id: feature-id, week: current-week })
    ))
  )
    (asserts! (is-eq (get owner feature-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set treatment-schedules
      { feature-id: feature-id, week: current-week }
      (merge schedule-data {
        scheduled-treatments: (+ (get scheduled-treatments schedule-data) u1)
      })
    )
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-water-feature-info (feature-id uint))
  (map-get? water-features { feature-id: feature-id })
)

(define-read-only (get-treatment-needed (feature-id uint))
  (match (map-get? water-features { feature-id: feature-id })
    feature-data
      (let (
        (last-treatment (get last-treatment feature-data))
        (interval (get treatment-interval feature-data))
        (algae-level (get algae-level feature-data))
      )
        (or
          (> (- block-height last-treatment) interval)
          (is-eq algae-level "high")
        )
      )
    false
  )
)

(define-read-only (get-water-quality-score (feature-id uint))
  (match (map-get? water-features { feature-id: feature-id })
    feature-data
      (let (
        (ph (get ph-level feature-data))
        (algae (get algae-level feature-data))
        (chemicals (get chemical-ppm feature-data))
      )
        ;; Simple scoring algorithm
        (if (and (>= ph u65) (<= ph u75) (is-eq algae "low") (< chemicals u25))
          u100
          u50
        )
      )
    u0
  )
)

(define-read-only (get-provider-info (provider principal))
  (map-get? cleaning-providers { provider: provider })
)
