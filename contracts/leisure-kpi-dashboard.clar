;; title: leisure-kpi-dashboard
;; version: 1.0.0
;; summary: Gamifies relaxation with metrics, deadlines, and performance reviews for weekend activities
;; description: Transforms leisure time into measurable KPIs with achievement rewards and quarterly reviews

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_ACTIVITY_NOT_FOUND (err u404))
(define-constant ERR_INVALID_SCORE (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_REVIEW_PERIOD_ACTIVE (err u403))
(define-constant POINTS_PER_HOUR u10)
(define-constant MAX_ACTIVITY_SCORE u10)
(define-constant QUARTERLY_REVIEW_BLOCKS u4320) ;; ~30 days in blocks
(define-constant ACHIEVEMENT_THRESHOLD u100)

;; data vars
(define-data-var activity-counter uint u0)
(define-data-var review-counter uint u0)
(define-data-var achievement-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;; data maps
(define-map activities
  { user: principal, activity-id: uint }
  {
    name: (string-ascii 50),
    duration-minutes: uint,
    productivity-score: uint,
    timestamp: uint,
    points-earned: uint,
    category: (string-ascii 20)
  }
)

(define-map user-stats
  { user: principal }
  {
    total-activities: uint,
    total-points: uint,
    current-streak: uint,
    best-streak: uint,
    last-activity-timestamp: uint,
    quarterly-target: uint,
    achievements-unlocked: uint
  }
)

(define-map activity-reviews
  { user: principal, review-id: uint }
  {
    period-start: uint,
    period-end: uint,
    activities-count: uint,
    average-score: uint,
    improvement-areas: (string-ascii 100),
    next-quarter-target: uint,
    performance-rating: (string-ascii 20)
  }
)

(define-map achievement-rewards
  { user: principal, achievement-id: uint }
  {
    name: (string-ascii 50),
    points-required: uint,
    reward-tokens: uint,
    unlocked-timestamp: uint
  }
)

;; private functions
(define-private (calculate-points (duration-minutes uint) (score uint))
  (let (
    (hours (/ duration-minutes u60))
    (base-points (* hours POINTS_PER_HOUR))
    (score-multiplier (/ score u5))
  )
    (* base-points score-multiplier)
  )
)

(define-private (update-user-streak (user principal) (timestamp uint))
  (let (
    (user-data (default-to
      { total-activities: u0, total-points: u0, current-streak: u0,
        best-streak: u0, last-activity-timestamp: u0, quarterly-target: u50,
        achievements-unlocked: u0 }
      (map-get? user-stats { user: user })
    ))
    (last-activity (get last-activity-timestamp user-data))
    (current-streak (get current-streak user-data))
    (time-diff (- timestamp last-activity))
  )
    (if (< time-diff u86400) ;; within 24 hours
      (+ current-streak u1)
      u1 ;; reset streak
    )
  )
)

(define-private (check-achievements (user principal) (total-points uint))
  (begin
    (if (and (>= total-points u50) (is-none (map-get? achievement-rewards { user: user, achievement-id: u1 })))
      (map-set achievement-rewards
        { user: user, achievement-id: u1 }
        {
          name: "First Steps to Optimization",
          points-required: u50,
          reward-tokens: u10,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    (if (and (>= total-points ACHIEVEMENT_THRESHOLD) (is-none (map-get? achievement-rewards { user: user, achievement-id: u2 })))
      (map-set achievement-rewards
        { user: user, achievement-id: u2 }
        {
          name: "Leisure Productivity Master",
          points-required: ACHIEVEMENT_THRESHOLD,
          reward-tokens: u25,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    (if (and (>= total-points u250) (is-none (map-get? achievement-rewards { user: user, achievement-id: u3 })))
      (map-set achievement-rewards
        { user: user, achievement-id: u3 }
        {
          name: "Work-Life Integration Champion",
          points-required: u250,
          reward-tokens: u50,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    true
  )
)

;; public functions
(define-public (log-activity (name (string-ascii 50)) (duration-minutes uint) (productivity-score uint) (category (string-ascii 20)))
  (let (
    (activity-id (+ (var-get activity-counter) u1))
    (points (calculate-points duration-minutes productivity-score))
    (user-data (default-to
      { total-activities: u0, total-points: u0, current-streak: u0,
        best-streak: u0, last-activity-timestamp: u0, quarterly-target: u50,
        achievements-unlocked: u0 }
      (map-get? user-stats { user: tx-sender })
    ))
        (new-streak (update-user-streak tx-sender stacks-block-height))
    (new-total-points (+ (get total-points user-data) points))
  )
    (asserts! (and (> duration-minutes u0) (<= productivity-score MAX_ACTIVITY_SCORE)) ERR_INVALID_SCORE)
    
    ;; Record the activity
    (map-set activities
      { user: tx-sender, activity-id: activity-id }
      {
        name: name,
        duration-minutes: duration-minutes,
        productivity-score: productivity-score,
        timestamp: stacks-block-height,
        points-earned: points,
        category: category
      }
    )
    
    ;; Update user stats
    (map-set user-stats
      { user: tx-sender }
      (merge user-data {
        total-activities: (+ (get total-activities user-data) u1),
        total-points: new-total-points,
        current-streak: new-streak,
        best-streak: (if (> new-streak (get best-streak user-data)) new-streak (get best-streak user-data)),
        last-activity-timestamp: stacks-block-height
      })
    )
    
    ;; Check for achievements
    (check-achievements tx-sender new-total-points)
    
    (var-set activity-counter activity-id)
    (ok activity-id)
  )
)

(define-public (conduct-quarterly-review (user principal))
  (let (
    (review-id (+ (var-get review-counter) u1))
    (user-data (unwrap! (map-get? user-stats { user: user }) ERR_NOT_AUTHORIZED))
    (period-start (- stacks-block-height QUARTERLY_REVIEW_BLOCKS))
    (activities-count (get total-activities user-data))
  )
    (asserts! (or (is-eq tx-sender user) (is-eq tx-sender (var-get contract-owner))) ERR_NOT_AUTHORIZED)
    
    (map-set activity-reviews
      { user: user, review-id: review-id }
      {
        period-start: period-start,
        period-end: stacks-block-height,
        activities-count: activities-count,
        average-score: (if (> activities-count u0) (/ (get total-points user-data) activities-count) u0),
        improvement-areas: "Focus on consistency and higher productivity scores",
        next-quarter-target: (+ (get quarterly-target user-data) u25),
        performance-rating: (if (>= (get total-points user-data) (get quarterly-target user-data)) "Exceeds Expectations" "Needs Improvement")
      }
    )
    
    (var-set review-counter review-id)
    (ok review-id)
  )
)

(define-public (set-quarterly-target (target uint))
  (let (
    (user-data (default-to
      { total-activities: u0, total-points: u0, current-streak: u0,
        best-streak: u0, last-activity-timestamp: u0, quarterly-target: u50,
        achievements-unlocked: u0 }
      (map-get? user-stats { user: tx-sender })
    ))
  )
    (map-set user-stats
      { user: tx-sender }
      (merge user-data { quarterly-target: target })
    )
    (ok true)
  )
)

(define-public (claim-achievement-reward (achievement-id uint))
  (let (
    (reward-data (unwrap! (map-get? achievement-rewards { user: tx-sender, achievement-id: achievement-id }) ERR_ACTIVITY_NOT_FOUND))
    (reward-tokens (get reward-tokens reward-data))
  )
    ;; In a real implementation, this would transfer tokens
    ;; For now, we'll just return success
    (ok reward-tokens)
  )
)

;; read only functions
(define-read-only (get-activity (user principal) (activity-id uint))
  (map-get? activities { user: user, activity-id: activity-id })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-quarterly-review (user principal) (review-id uint))
  (map-get? activity-reviews { user: user, review-id: review-id })
)

(define-read-only (get-achievement (user principal) (achievement-id uint))
  (map-get? achievement-rewards { user: user, achievement-id: achievement-id })
)

(define-read-only (calculate-productivity-rank (user principal))
  (let (
    (user-data (unwrap! (map-get? user-stats { user: user }) ERR_NOT_AUTHORIZED))
    (total-points (get total-points user-data))
  )
    (ok (if (>= total-points u500)
      "Optimization Guru"
      (if (>= total-points u250)
        "Integration Master"
        (if (>= total-points u100)
          "Productivity Enthusiast"
          (if (>= total-points u50)
            "Efficiency Seeker"
            "Leisure Novice"
          )
        )
      )
    ))
  )
)

