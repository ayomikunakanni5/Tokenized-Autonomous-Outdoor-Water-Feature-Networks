;; Wildlife Safety Contract
;; Ensures water features remain safe for birds and animals

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-FEATURE-ID (err u501))
(define-constant ERR-UNSAFE-CONDITIONS (err u502))
(define-constant ERR-MIGRATION-SEASON (err u503))

;; Data Variables
(define-data-var min-safe-depth uint u2) ;; 2 inches minimum
(define-data-var max-safe-depth uint u12) ;; 12 inches maximum
(define-data-var safety-inspection-fee uint u750000) ;; 0.75 STX

;; Data Maps
(define-map wildlife-safe-features
  { feature-id: uint }
  {
    owner: principal,
    water-depth: uint,
    has-escape-routes: bool,
    bird-landing-areas: uint,
    chemical-free-zones: bool,
    last-safety-check: uint,
    wildlife-incidents: uint,
    seasonal-modifications: bool
  }
)

(define-map wildlife-observations
  { feature-id: uint, observation-date: uint }
  {
    observer: principal,
    species-observed: (string-ascii 50),
    animal-count: uint,
    behavior-notes: (string-ascii 200),
    safety-concerns: bool
  }
)

(define-map seasonal-wildlife-data
  { season: (string-ascii 10), region: (string-ascii 20) }
  {
    migration-active: bool,
    protected-species-present: bool,
    nesting-season: bool,
    feeding-restrictions: bool
  }
)

(define-map wildlife-specialists
  { specialist: principal }
  {
    safety-inspections-completed: uint,
    wildlife-rescues-performed: uint,
    habitat-modifications-made: uint,
    conservation-certified: bool
  }
)

;; Public Functions

;; Register feature for wildlife safety monitoring
(define-public (register-wildlife-safety (feature-id uint) (initial-depth uint) (landing-areas uint))
  (begin
    (asserts! (is-none (map-get? wildlife-safe-features { feature-id: feature-id })) ERR-INVALID-FEATURE-ID)
    (asserts! (and (>= initial-depth (var-get min-safe-depth)) (<= initial-depth (var-get max-safe-depth))) ERR-UNSAFE-CONDITIONS)

    (map-set wildlife-safe-features
      { feature-id: feature-id }
      {
        owner: tx-sender,
        water-depth: initial-depth,
        has-escape-routes: true,
        bird-landing-areas: landing-areas,
        chemical-free-zones: true,
        last-safety-check: block-height,
        wildlife-incidents: u0,
        seasonal-modifications: false
      }
    )
    (ok feature-id)
  )
)

;; Conduct safety inspection
(define-public (conduct-safety-inspection (feature-id uint) (depth-measurement uint) (escape-routes-clear bool))
  (let (
    (feature-data (unwrap! (map-get? wildlife-safe-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (specialist-data (default-to
      { safety-inspections-completed: u0, wildlife-rescues-performed: u0, habitat-modifications-made: u0, conservation-certified: false }
      (map-get? wildlife-specialists { specialist: tx-sender })
    ))
  )
    (asserts! (and (>= depth-measurement (var-get min-safe-depth)) (<= depth-measurement (var-get max-safe-depth))) ERR-UNSAFE-CONDITIONS)

    ;; Update feature safety data
    (map-set wildlife-safe-features
      { feature-id: feature-id }
      (merge feature-data {
        water-depth: depth-measurement,
        has-escape-routes: escape-routes-clear,
        last-safety-check: block-height
      })
    )

    ;; Update specialist stats
    (map-set wildlife-specialists
      { specialist: tx-sender }
      (merge specialist-data {
        safety-inspections-completed: (+ (get safety-inspections-completed specialist-data) u1)
      })
    )

    (ok true)
  )
)

;; Record wildlife observation
(define-public (record-wildlife-observation (feature-id uint) (species (string-ascii 50)) (count uint) (notes (string-ascii 200)))
  (let (
    (feature-data (unwrap! (map-get? wildlife-safe-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
  )
    (map-set wildlife-observations
      { feature-id: feature-id, observation-date: block-height }
      {
        observer: tx-sender,
        species-observed: species,
        animal-count: count,
        behavior-notes: notes,
        safety-concerns: false
      }
    )
    (ok true)
  )
)

;; Report wildlife incident
(define-public (report-wildlife-incident (feature-id uint) (incident-details (string-ascii 200)))
  (let (
    (feature-data (unwrap! (map-get? wildlife-safe-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
  )
    ;; Record incident observation
    (map-set wildlife-observations
      { feature-id: feature-id, observation-date: block-height }
      {
        observer: tx-sender,
        species-observed: "incident",
        animal-count: u1,
        behavior-notes: incident-details,
        safety-concerns: true
      }
    )

    ;; Increment incident counter
    (map-set wildlife-safe-features
      { feature-id: feature-id }
      (merge feature-data {
        wildlife-incidents: (+ (get wildlife-incidents feature-data) u1)
      })
    )

    (ok true)
  )
)

;; Install wildlife safety modifications
(define-public (install-safety-modifications (feature-id uint) (modification-type (string-ascii 50)))
  (let (
    (feature-data (unwrap! (map-get? wildlife-safe-features { feature-id: feature-id }) ERR-INVALID-FEATURE-ID))
    (specialist-data (default-to
      { safety-inspections-completed: u0, wildlife-rescues-performed: u0, habitat-modifications-made: u0, conservation-certified: false }
      (map-get? wildlife-specialists { specialist: tx-sender })
    ))
  )
    (asserts! (get conservation-certified specialist-data) ERR-NOT-AUTHORIZED)

    (map-set wildlife-safe-features
      { feature-id: feature-id }
      (merge feature-data {
        seasonal-modifications: true
      })
    )

    ;; Update specialist stats
    (map-set wildlife-specialists
      { specialist: tx-sender }
      (merge specialist-data {
        habitat-modifications-made: (+ (get habitat-modifications-made specialist-data) u1)
      })
    )

    (ok true)
  )
)

;; Update seasonal wildlife data
(define-public (update-seasonal-data (season (string-ascii 10)) (region (string-ascii 20)) (migration-active bool) (nesting-season bool))
  (begin
    (map-set seasonal-wildlife-data
      { season: season, region: region }
      {
        migration-active: migration-active,
        protected-species-present: migration-active,
        nesting-season: nesting-season,
        feeding-restrictions: nesting-season
      }
    )
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-wildlife-feature-info (feature-id uint))
  (map-get? wildlife-safe-features { feature-id: feature-id })
)

(define-read-only (get-safety-status (feature-id uint))
  (match (map-get? wildlife-safe-features { feature-id: feature-id })
    feature-data
      {
        depth-safe: (and
          (>= (get water-depth feature-data) (var-get min-safe-depth))
          (<= (get water-depth feature-data) (var-get max-safe-depth))
        ),
        escape-routes-clear: (get has-escape-routes feature-data),
        chemical-free: (get chemical-free-zones feature-data),
        recent-inspection: (< (- block-height (get last-safety-check feature-data)) u1440), ;; Within 1440 blocks
        incident-free: (is-eq (get wildlife-incidents feature-data) u0)
      }
    {
      depth-safe: false,
      escape-routes-clear: false,
      chemical-free: false,
      recent-inspection: false,
      incident-free: false
    }
  )
)

(define-read-only (get-wildlife-observations (feature-id uint) (date uint))
  (map-get? wildlife-observations { feature-id: feature-id, observation-date: date })
)

(define-read-only (get-seasonal-restrictions (season (string-ascii 10)) (region (string-ascii 20)))
  (map-get? seasonal-wildlife-data { season: season, region: region })
)

(define-read-only (is-migration-season (season (string-ascii 10)) (region (string-ascii 20)))
  (match (map-get? seasonal-wildlife-data { season: season, region: region })
    seasonal-data (get migration-active seasonal-data)
    false
  )
)

(define-read-only (get-specialist-credentials (specialist principal))
  (map-get? wildlife-specialists { specialist: specialist })
)

(define-read-only (calculate-wildlife-safety-score (feature-id uint))
  (match (map-get? wildlife-safe-features { feature-id: feature-id })
    feature-data
      (let (
        (depth-score (if (and (>= (get water-depth feature-data) (var-get min-safe-depth))
                             (<= (get water-depth feature-data) (var-get max-safe-depth))) u25 u0))
        (escape-score (if (get has-escape-routes feature-data) u25 u0))
        (chemical-score (if (get chemical-free-zones feature-data) u25 u0))
        (incident-score (if (is-eq (get wildlife-incidents feature-data) u0) u25 u0))
      )
        (+ depth-score escape-score chemical-score incident-score)
      )
    u0
  )
)
