;; title: mindfulness-notification-storm
;; version: 1.0.0
;; summary: Sends 47 push notifications per day reminding you to be present in the moment
;; description: Manages mindfulness reminders through notification scheduling, presence tracking, and streak management

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_USER_NOT_FOUND (err u404))
(define-constant ERR_INVALID_NOTIFICATION_COUNT (err u400))
(define-constant ERR_STREAK_BROKEN (err u402))
(define-constant ERR_NOTIFICATION_NOT_FOUND (err u403))
(define-constant MAX_DAILY_NOTIFICATIONS u47)
(define-constant MIN_DAILY_NOTIFICATIONS u5)
(define-constant STREAK_RESET_THRESHOLD u172800) ;; 48 hours in seconds
(define-constant MINDFULNESS_POINTS_PER_SESSION u5)
(define-constant PRESENCE_MULTIPLIER u2)
(define-constant BLOCKS_PER_DAY u144) ;; approximately 144 blocks per day

;; data vars
(define-data-var notification-counter uint u0)
(define-data-var session-counter uint u0)
(define-data-var global-presence-score uint u0)
(define-data-var contract-owner principal tx-sender)

;; data maps
(define-map user-notification-settings
  { user: principal }
  {
    daily-notification-count: uint,
    notification-intensity: (string-ascii 10),
    active: bool,
    last-setup-timestamp: uint,
    custom-messages: (list 5 (string-ascii 100)),
    preferred-intervals: (list 47 uint)
  }
)

(define-map notification-schedule
  { user: principal, notification-id: uint }
  {
    message: (string-ascii 100),
    scheduled-block: uint,
    sent-block: (optional uint),
    acknowledged: bool,
    presence-score: uint,
    mindfulness-type: (string-ascii 20)
  }
)

(define-map mindfulness-sessions
  { user: principal, session-id: uint }
  {
    start-timestamp: uint,
    duration-seconds: uint,
    presence-quality: uint,
    breathing-rhythm: uint,
    focus-level: uint,
    distractions-count: uint,
    session-type: (string-ascii 20)
  }
)

(define-map user-mindfulness-stats
  { user: principal }
  {
    total-sessions: uint,
    current-streak: uint,
    longest-streak: uint,
    total-mindfulness-time: uint,
    average-presence-score: uint,
    last-session-timestamp: uint,
    notifications-acknowledged-today: uint,
    mindfulness-level: (string-ascii 20)
  }
)

(define-map daily-presence-tracking
  { user: principal, day: uint }
  {
    notifications-sent: uint,
    notifications-acknowledged: uint,
    mindfulness-sessions: uint,
    total-presence-time: uint,
    daily-score: uint,
    missed-opportunities: uint
  }
)

(define-map presence-achievements
  { user: principal, achievement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 100),
    requirement: uint,
    reward-points: uint,
    unlocked-timestamp: uint
  }
)

;; private functions
(define-private (calculate-presence-score (duration uint) (focus-level uint) (distractions uint))
  (let (
    (base-score (* duration MINDFULNESS_POINTS_PER_SESSION))
    (focus-bonus (* focus-level PRESENCE_MULTIPLIER))
    (distraction-penalty (* distractions u2))
    (final-score (- (+ base-score focus-bonus) distraction-penalty))
  )
    (if (> final-score u0) final-score u0)
  )
)

(define-private (update-mindfulness-streak (user principal) (current-timestamp uint))
  (let (
    (user-stats (default-to
      { total-sessions: u0, current-streak: u0, longest-streak: u0,
        total-mindfulness-time: u0, average-presence-score: u0,
        last-session-timestamp: u0, notifications-acknowledged-today: u0,
        mindfulness-level: "Novice" }
      (map-get? user-mindfulness-stats { user: user })
    ))
    (last-session (get last-session-timestamp user-stats))
    (time-diff (- current-timestamp last-session))
    (current-streak (get current-streak user-stats))
  )
    (if (< time-diff STREAK_RESET_THRESHOLD)
      (+ current-streak u1)
      u1 ;; reset streak if gap is too long
    )
  )
)

(define-private (determine-mindfulness-level (total-sessions uint) (average-score uint))
  (if (and (>= total-sessions u100) (>= average-score u80))
    "Zen Master"
    (if (and (>= total-sessions u50) (>= average-score u60))
      "Mindfulness Adept"
      (if (and (>= total-sessions u20) (>= average-score u40))
        "Present Practitioner"
        (if (and (>= total-sessions u5) (>= average-score u20))
          "Awareness Seeker"
          "Novice"
        )
      )
    )
  )
)

(define-private (check-presence-achievements (user principal) (total-sessions uint) (current-streak uint))
  (begin
    ;; First Moment Achievement
    (if (and (>= total-sessions u1) (is-none (map-get? presence-achievements { user: user, achievement-id: u1 })))
      (map-set presence-achievements
        { user: user, achievement-id: u1 }
        {
          name: "First Moment of Awareness",
          description: "Completed your first mindfulness session",
          requirement: u1,
          reward-points: u10,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    
    ;; Consistent Practice Achievement
    (if (and (>= current-streak u7) (is-none (map-get? presence-achievements { user: user, achievement-id: u2 })))
      (map-set presence-achievements
        { user: user, achievement-id: u2 }
        {
          name: "Week of Presence",
          description: "Maintained mindfulness practice for 7 consecutive days",
          requirement: u7,
          reward-points: u25,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    
    ;; Notification Master Achievement
    (if (and (>= total-sessions u47) (is-none (map-get? presence-achievements { user: user, achievement-id: u3 })))
      (map-set presence-achievements
        { user: user, achievement-id: u3 }
        {
          name: "Notification Storm Survivor",
          description: "Acknowledged all 47 daily notifications",
          requirement: u47,
          reward-points: u50,
          unlocked-timestamp: stacks-block-height
        }
      )
      false
    )
    true
  )
)

;; public functions
(define-public (setup-daily-reminders (notification-count uint) (intensity (string-ascii 10)))
  (let (
    (custom-messages (list
      "Be present in this moment - your KPIs depend on it"
      "Mindfulness alert: Check your awareness metrics"
      "Present moment ROI calculation in progress"
      "Optimization opportunity: Focus on your breathing"
      "Performance review: How present are you right now?"
    ))
    (default-intervals (list u30 u60 u90 u120 u150 u180 u210 u240 u270 u300 u330 u360 u390 u420 u450 u480 u510 u540 u570 u600 u630 u660 u690 u720 u750 u780 u810 u840 u870 u900 u930 u960 u990 u1020 u1050 u1080 u1110 u1140 u1170 u1200 u1230 u1260 u1290 u1320 u1350 u1380 u1410))
  )
    (asserts! (and (>= notification-count MIN_DAILY_NOTIFICATIONS) (<= notification-count MAX_DAILY_NOTIFICATIONS)) ERR_INVALID_NOTIFICATION_COUNT)
    
    (map-set user-notification-settings
      { user: tx-sender }
      {
        daily-notification-count: notification-count,
        notification-intensity: intensity,
        active: true,
        last-setup-timestamp: stacks-block-height,
        custom-messages: custom-messages,
        preferred-intervals: default-intervals
      }
    )
    (ok notification-count)
  )
)

(define-public (acknowledge-notification (notification-id uint) (presence-rating uint))
  (let (
    (notification-data (unwrap! (map-get? notification-schedule { user: tx-sender, notification-id: notification-id }) ERR_NOTIFICATION_NOT_FOUND))
    (presence-score (* presence-rating PRESENCE_MULTIPLIER))
  )
    (asserts! (<= presence-rating u10) ERR_INVALID_NOTIFICATION_COUNT)
    
    ;; Update notification as acknowledged
    (map-set notification-schedule
      { user: tx-sender, notification-id: notification-id }
      (merge notification-data {
        acknowledged: true,
        presence-score: presence-score
      })
    )
    
    ;; Update daily tracking
    (let (
      (today (/ stacks-block-height BLOCKS_PER_DAY))
      (daily-data (default-to
        { notifications-sent: u0, notifications-acknowledged: u0,
          mindfulness-sessions: u0, total-presence-time: u0,
          daily-score: u0, missed-opportunities: u0 }
        (map-get? daily-presence-tracking { user: tx-sender, day: today })
      ))
    )
      (map-set daily-presence-tracking
        { user: tx-sender, day: today }
        (merge daily-data {
          notifications-acknowledged: (+ (get notifications-acknowledged daily-data) u1),
          daily-score: (+ (get daily-score daily-data) presence-score)
        })
      )
    )
    (ok presence-score)
  )
)

(define-public (start-mindfulness-session (session-type (string-ascii 20)))
  (let (
    (session-id (+ (var-get session-counter) u1))
  )
    (map-set mindfulness-sessions
      { user: tx-sender, session-id: session-id }
      {
        start-timestamp: stacks-block-height,
        duration-seconds: u0,
        presence-quality: u0,
        breathing-rhythm: u0,
        focus-level: u0,
        distractions-count: u0,
        session-type: session-type
      }
    )
    (var-set session-counter session-id)
    (ok session-id)
  )
)

(define-public (complete-mindfulness-session (session-id uint) (duration uint) (focus-level uint) (distractions uint))
  (let (
    (session-data (unwrap! (map-get? mindfulness-sessions { user: tx-sender, session-id: session-id }) ERR_USER_NOT_FOUND))
    (presence-score (calculate-presence-score duration focus-level distractions))
    (breathing-rhythm (if (> focus-level u5) u10 u5))
    (user-stats (default-to
      { total-sessions: u0, current-streak: u0, longest-streak: u0,
        total-mindfulness-time: u0, average-presence-score: u0,
        last-session-timestamp: u0, notifications-acknowledged-today: u0,
        mindfulness-level: "Novice" }
      (map-get? user-mindfulness-stats { user: tx-sender })
    ))
    (new-streak (update-mindfulness-streak tx-sender stacks-block-height))
    (new-total-time (+ (get total-mindfulness-time user-stats) duration))
    (new-session-count (+ (get total-sessions user-stats) u1))
    (new-average-score (/ (+ (* (get average-presence-score user-stats) (get total-sessions user-stats)) presence-score) new-session-count))
  )
    (asserts! (<= focus-level u10) ERR_INVALID_NOTIFICATION_COUNT)
    
    ;; Update session completion
    (map-set mindfulness-sessions
      { user: tx-sender, session-id: session-id }
      (merge session-data {
        duration-seconds: duration,
        presence-quality: presence-score,
        breathing-rhythm: breathing-rhythm,
        focus-level: focus-level,
        distractions-count: distractions
      })
    )
    
    ;; Update user stats
    (map-set user-mindfulness-stats
      { user: tx-sender }
      {
        total-sessions: new-session-count,
        current-streak: new-streak,
        longest-streak: (if (> new-streak (get longest-streak user-stats)) new-streak (get longest-streak user-stats)),
        total-mindfulness-time: new-total-time,
        average-presence-score: new-average-score,
        last-session-timestamp: stacks-block-height,
        notifications-acknowledged-today: (get notifications-acknowledged-today user-stats),
        mindfulness-level: (determine-mindfulness-level new-session-count new-average-score)
      }
    )
    
    ;; Check achievements
    (check-presence-achievements tx-sender new-session-count new-streak)
    
    ;; Update daily tracking
    (let (
      (today (/ stacks-block-height BLOCKS_PER_DAY))
      (daily-data (default-to
        { notifications-sent: u0, notifications-acknowledged: u0,
          mindfulness-sessions: u0, total-presence-time: u0,
          daily-score: u0, missed-opportunities: u0 }
        (map-get? daily-presence-tracking { user: tx-sender, day: today })
      ))
    )
      (map-set daily-presence-tracking
        { user: tx-sender, day: today }
        (merge daily-data {
          mindfulness-sessions: (+ (get mindfulness-sessions daily-data) u1),
          total-presence-time: (+ (get total-presence-time daily-data) duration),
          daily-score: (+ (get daily-score daily-data) presence-score)
        })
      )
    )
    (ok presence-score)
  )
)

(define-public (schedule-notification (message (string-ascii 100)) (target-block uint) (mindfulness-type (string-ascii 20)))
  (let (
    (notification-id (+ (var-get notification-counter) u1))
    (user-settings (unwrap! (map-get? user-notification-settings { user: tx-sender }) ERR_USER_NOT_FOUND))
  )
    (asserts! (get active user-settings) ERR_NOT_AUTHORIZED)
    
    (map-set notification-schedule
      { user: tx-sender, notification-id: notification-id }
      {
        message: message,
        scheduled-block: target-block,
        sent-block: none,
        acknowledged: false,
        presence-score: u0,
        mindfulness-type: mindfulness-type
      }
    )
    
    (var-set notification-counter notification-id)
    (ok notification-id)
  )
)

(define-public (update-notification-intensity (new-intensity (string-ascii 10)))
  (let (
    (current-settings (unwrap! (map-get? user-notification-settings { user: tx-sender }) ERR_USER_NOT_FOUND))
  )
    (map-set user-notification-settings
      { user: tx-sender }
      (merge current-settings { notification-intensity: new-intensity })
    )
    (ok true)
  )
)

;; read only functions
(define-read-only (get-user-notification-settings (user principal))
  (map-get? user-notification-settings { user: user })
)

(define-read-only (get-notification (user principal) (notification-id uint))
  (map-get? notification-schedule { user: user, notification-id: notification-id })
)

(define-read-only (get-mindfulness-session (user principal) (session-id uint))
  (map-get? mindfulness-sessions { user: user, session-id: session-id })
)

(define-read-only (get-user-mindfulness-stats (user principal))
  (map-get? user-mindfulness-stats { user: user })
)

(define-read-only (get-daily-presence-tracking (user principal) (day uint))
  (map-get? daily-presence-tracking { user: user, day: day })
)

(define-read-only (get-presence-achievement (user principal) (achievement-id uint))
  (map-get? presence-achievements { user: user, achievement-id: achievement-id })
)

(define-read-only (calculate-mindfulness-efficiency (user principal))
  (let (
    (user-stats (unwrap! (map-get? user-mindfulness-stats { user: user }) ERR_USER_NOT_FOUND))
    (total-time (get total-mindfulness-time user-stats))
    (total-sessions (get total-sessions user-stats))
    (average-session-time (if (> total-sessions u0) (/ total-time total-sessions) u0))
  )
    (ok {
      average-session-duration: average-session-time,
      efficiency-score: (get average-presence-score user-stats),
      optimization-potential: (- u100 (get average-presence-score user-stats))
    })
  )
)

