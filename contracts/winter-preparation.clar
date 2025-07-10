;; Winter Preparation Contract
;; Handles seasonal drainage and freeze protection for outdoor water features

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-FEATURE-ID (err u301))
(define-constant ERR-WRONG-SEASON (err u302))
(define-constant ERR-ALREADY-WINTERIZED (err u303))

;; Data Variables
(define-data-var winterization-fee uint u2000000) ;; 2 STX in microSTX
(define-data-var freeze-threshold-temp int 32) ;; Fahrenheit

;; Data Maps
(define-map seasonal-features
  { feature-id: uint }
  {
    owner: principal,
    is-winterized: bool,
    last-winterization: uint,
    last-spring-activation: uint,
    drainage-complete: bool,
    freeze-protection-active: bool,
    equipment-stored: bool
  }
)

(define-map weather-data
  { date: uint }
  {
    temperature: int,
    forecast-days: uint,
    freeze-warning: bool,
    season: (string-ascii 10)
  }
)

(define-map winterization-providers
  { provider: principal }
  {
    seasonal-jobs-completed: uint,
    equipment-handling-certified: bool,
    drainage-specialist: bool,
    spring-activation-rating: uint
  }
)

;; Public Functions

;; Register feature for seasonal management
(define-public (register-seasonal-feature (feature-id uint))
  (begin
    (asserts! (is-none (map-get? seasonal-features { feature-id: feature-id })) ERR-INVALID-FEATURE-ID)
    (map-set seasonal-features
      { feature-id: feature-id }
      {
        owner: tx-sender,
        is-winterized: false,
        last-winterization: u0,
        last-spring-activation: u0,
        drainage-complete: false,
        freeze-protection-active: false,
        equipment-stored: false
      }
    )
    (ok feature-id)
  )
)

;; Begin winterization process
(define-public (begin-winterization (feature-id uint))
  (let (
    (feature-data (unwrap! (map-get? seasonal-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (provider-data (default-to
      { seasonal-jobs-completed: u0, equipment-handling-certified: false, drainage-specialist: false, spring-activation-rating: u0 }
      (map-get? winterization-providers { provider: tx-sender })
    ))
  )
    (asserts! (not (get is-winterized feature-data)) ERR-ALREADY-WINTERIZED)

    ;; Start winterization process
    (map-set seasonal-features
      { feature-id: feature-id }
      (merge feature-data {
        is-winterized: true,
        last-winterization: block-height,
        drainage-complete: false,
        freeze-protection-active: true,
        equipment-stored: false
      })
    )

    (ok true)
  )
)

;; Complete drainage
(define-public (complete-drainage (feature-id uint))
  (let (
    (feature-data (unwrap! (map-get? seasonal-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
  )
    (asserts! (get is-winterized feature-data) ERR-WRONG-SEASON)

    (map-set seasonal-features
      { feature-id: feature-id }
      (merge feature-data {
        drainage-complete: true
      })
    )
    (ok true)
  )
)

;; Store equipment for winter
(define-public (store-equipment (feature-id uint))
  (let (
    (feature-data (unwrap! (map-get? seasonal-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (provider-data (default-to
      { seasonal-jobs-completed: u0, equipment-handling-certified: false, drainage-specialist: false, spring-activation-rating: u0 }
      (map-get? winterization-providers { provider: tx-sender })
    ))
  )
    (asserts! (get drainage-complete feature-data) ERR-WRONG-SEASON)
    (asserts! (get equipment-handling-certified provider-data) ERR-NOT-AUTHORIZED)

    (map-set seasonal-features
      { feature-id: feature-id }
      (merge feature-data {
        equipment-stored: true
      })
    )

    ;; Update provider stats
    (map-set winterization-providers
      { provider: tx-sender }
      (merge provider-data {
        seasonal-jobs-completed: (+ (get seasonal-jobs-completed provider-data) u1)
      })
    )

    (ok true)
  )
)

;; Spring reactivation
(define-public (spring-reactivation (feature-id uint))
  (let (
    (feature-data (unwrap! (map-get? seasonal-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
  )
    (asserts! (get is-winterized feature-data) ERR-WRONG-SEASON)

    (map-set seasonal-features
      { feature-id: feature-id }
      (merge feature-data {
        is-winterized: false,
        last-spring-activation: block-height,
        drainage-complete: false,
        freeze-protection-active: false,
        equipment-stored: false
      })
    )
    (ok true)
  )
)

;; Update weather data
(define-public (update-weather (temperature int) (forecast-days uint) (season (string-ascii 10)))
  (let (
    (freeze-warning (< temperature (var-get freeze-threshold-temp)))
  )
    (map-set weather-data
      { date: block-height }
      {
        temperature: temperature,
        forecast-days: forecast-days,
        freeze-warning: freeze-warning,
        season: season
      }
    )
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-seasonal-feature-info (feature-id uint))
  (map-get? seasonal-features { feature-id: feature-id })
)

(define-read-only (get-winterization-status (feature-id uint))
  (match (map-get? seasonal-features { feature-id: feature-id })
    feature-data
      {
        is-winterized: (get is-winterized feature-data),
        drainage-complete: (get drainage-complete feature-data),
        equipment-stored: (get equipment-stored feature-data),
        ready-for-winter: (and
          (get is-winterized feature-data)
          (get drainage-complete feature-data)
          (get equipment-stored feature-data)
        )
      }
    {
      is-winterized: false,
      drainage-complete: false,
      equipment-stored: false,
      ready-for-winter: false
    }
  )
)

(define-read-only (get-current-weather)
  (map-get? weather-data { date: block-height })
)

(define-read-only (get-freeze-warning)
  (match (map-get? weather-data { date: block-height })
    weather-info (get freeze-warning weather-info)
    false
  )
)

(define-read-only (get-provider-credentials (provider principal))
  (map-get? winterization-providers { provider: provider })
)
