<template>
    <div v-if="$slidev.nav.isPresenter" class="timer-bar">
        <div class="w-1px opacity-10 bg-current m-1 lg:m-2"></div>

        <PresentationTimer :presentation-start-time="presentationStartTime"
            :presentation-has-started="presentationHasStarted" :current-time="currentTime" />

        <SlideTimerNav :current-slide-elapsed="currentSlideElapsed"
            :current-slide-planned-minutes="currentSlidePlannedMinutes"
            :presentation-has-started="presentationHasStarted" />

        <BankedTimeNav :banked-time-minutes="bankedTimeMinutes" :presentation-start-time="presentationStartTime"
            :completed-slides="completedSlides" :scheduling-delta-minutes="schedulingDeltaMinutes"
            :dynamic-banking-minutes="dynamicBankingMinutes" :time-delta-info="timeDeltaInfo" />

        <BreaksNav v-if="hasBreaks" :presentation-elapsed-minutes="presentationElapsedMinutes"
            :presentation-has-started="presentationHasStarted" :current-time="currentTime" />

        <EstimatedEndTimeNav :estimated-end-time="estimatedEndTime" :banked-time-minutes="bankedTimeMinutes"
            :remaining-time-minutes="remainingTimeMinutes" :target-completion-time="targetCompletionTime"
            :presentation-start-time="presentationStartTime" :current-slide-elapsed="currentSlideElapsed"
            :current-time="currentTime" :remaining-breaks-info="remainingBreaksInfo" />

        <TargetCompletionTime :target-completion-time="targetCompletionTime" />

        <div class="w-1px opacity-10 bg-current m-1 lg:m-2"></div>
    </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue'
import PresentationTimer from './PresentationTimer.vue'
import SlideTimerNav from './SlideTimerNav.vue'
import BankedTimeNav from './BankedTimeNav.vue'
import EstimatedEndTimeNav from './EstimatedEndTimeNav.vue'
import TargetCompletionTime from './TargetCompletionTime.vue'
import BreaksNav from './BreaksNav.vue'

// Storage keys
const STORAGE_KEY_PREFIX = 'slidev-turtle-'
const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`
const SLIDE_TIMES_KEY = 'slidev-turtle-slide-times'
const PRESENTATION_START_KEY = 'slidev-turtle-presentation-start-time'
const TARGET_COMPLETION_KEY = `${STORAGE_KEY_PREFIX}target-completion`
const BREAKS_KEY = `${STORAGE_KEY_PREFIX}breaks`
const BREAK_TIMES_KEY = `${STORAGE_KEY_PREFIX}break-times`

// Reactive data
const currentTime = ref(Date.now())
const intervalId = ref(null)
const presentationStartTime = ref(null)
const targetCompletionTime = ref(null)
const slideStartTime = ref(Date.now())
const breaks = ref([])
const breakTimes = ref({})

// Load data from localStorage
const loadStoredData = () => {
    const startTime = localStorage.getItem(PRESENTATION_START_KEY)
    if (startTime) {
        presentationStartTime.value = parseInt(startTime)
    }

    const targetTime = localStorage.getItem(TARGET_COMPLETION_KEY)
    if (targetTime) {
        targetCompletionTime.value = parseInt(targetTime)
    }
}

// Load breaks from storage
const loadBreaks = () => {
    try {
        const storedBreaks = localStorage.getItem(BREAKS_KEY)
        breaks.value = storedBreaks ? JSON.parse(storedBreaks) : []
    } catch (e) {
        breaks.value = []
    }
}

// Load break times from storage
const loadBreakTimes = () => {
    try {
        const storedBreakTimes = localStorage.getItem(BREAK_TIMES_KEY)
        breakTimes.value = storedBreakTimes ? JSON.parse(storedBreakTimes) : {}
    } catch (e) {
        breakTimes.value = {}
    }
}

// Check if presentation has started
const presentationHasStarted = computed(() => {
    if (!presentationStartTime.value) return true // No start time set, consider started
    return currentTime.value >= presentationStartTime.value
})

// Calculate presentation elapsed time in minutes
const presentationElapsedMinutes = computed(() => {
    if (!presentationHasStarted.value || !presentationStartTime.value) {
        return 0
    }
    return (currentTime.value - presentationStartTime.value) / (60 * 1000)
})

// Check if breaks are configured
const hasBreaks = computed(() => {
    if (breaks.value.length === 0) return false

    // Check if there are any upcoming breaks (not completed, not skipped)
    const now = new Date()
    const currentTimeMinutes = now.getHours() * 60 + now.getMinutes()

    return breaks.value.some(breakItem => {
        const breakId = `${breakItem.targetTime}-${breakItem.durationMinutes}-${breakItem.label}`
        const breakRecord = breakTimes.value[breakId]

        // If break has been completed or skipped, don't count it
        if (breakRecord && (breakRecord.completed || breakRecord.skipped)) {
            return false
        }

        // Check if break time is in the future
        const [hours, minutes] = (breakItem.targetTime || '00:00').split(':').map(Number)
        const targetTimeMinutes = hours * 60 + minutes

        return targetTimeMinutes >= currentTimeMinutes
    })
})

// Calculate total planned time including breaks
const totalPlannedTimeWithBreaks = computed(() => {
    const slidesTime = slideTimes.value.reduce((sum, slideTime) => sum + slideTime, 0)
    const breaksTime = breaks.value.reduce((sum, breakItem) => sum + (breakItem.durationMinutes || 0), 0)
    return slidesTime + breaksTime
})

// Get slide times from configuration
const slideTimes = computed(() => {
    const slides = $slidev.nav.slides
    const defaultSlideTime = $slidev.configs?.rabbit?.defaultSlideTime || 2

    return slides.map(slide => {
        const slideTime = slide.meta.slide.frontmatter?.slideTime
        const time = slideTime !== undefined ? parseFloat(slideTime) : defaultSlideTime
        return !isNaN(time) && time > 0 ? time : defaultSlideTime
    })
})

// Current slide elapsed time - calculated directly here, no delegation needed
const currentSlideElapsed = computed(() => {
    const slideNum = $slidev.nav.currentPage
    const storedTime = slideElapsedTimes.value[slideNum] || 0

    // Only count session time if presentation has started
    if (!presentationHasStarted.value) {
        return storedTime
    }

    // Calculate session time, but only from when presentation actually started
    // If slideStartTime is before presentation start, use presentation start time instead
    const effectiveStartTime = Math.max(slideStartTime.value, presentationStartTime.value || slideStartTime.value)
    const sessionTime = Math.max(0, (currentTime.value - effectiveStartTime) / 1000)

    return storedTime + sessionTime
})

// Current slide planned time in minutes
const currentSlidePlannedMinutes = computed(() => {
    const currentSlideIndex = $slidev.nav.currentPage - 1
    return slideTimes.value[currentSlideIndex] || 2
})

// Number of completed slides
const completedSlides = computed(() => {
    return Math.max(0, $slidev.nav.currentPage - 1)
})

// Reactive slide elapsed times that updates when localStorage changes
const slideElapsedTimes = ref({})

// Function to load slide elapsed times
const loadSlideElapsedTimes = () => {
    try {
        const saved = localStorage.getItem(SLIDE_TIMES_KEY)
        slideElapsedTimes.value = saved ? JSON.parse(saved) : {}
    } catch (e) {
        slideElapsedTimes.value = {}
    }
}

// Start timing for current slide
const startSlideTimer = () => {
    // If presentation hasn't started yet, set slide start time to presentation start time
    // This ensures we don't count time before the presentation begins
    if (!presentationHasStarted.value && presentationStartTime.value) {
        slideStartTime.value = presentationStartTime.value
    } else {
        // Reset the slide start time to current time for accurate session tracking
        slideStartTime.value = currentTime.value
    }
}

// Save current slide time 
const saveCurrentSlideTime = () => {
    const slideNum = $slidev.nav.currentPage

    // Use our calculated current slide elapsed time
    const totalElapsedTime = currentSlideElapsed.value

    // Store the elapsed time for this slide
    slideElapsedTimes.value[slideNum] = totalElapsedTime
    localStorage.setItem(SLIDE_TIMES_KEY, JSON.stringify(slideElapsedTimes.value))
}

// Banked time calculation: net time advantage/deficit relative to target
// Bank = (Target - Start - TotalPlannedTime) + SlidePerformanceDelta + BreakPerformanceDelta
const bankedTimeMinutes = computed(() => {
    let bankedTime = 0

    // 1. Base scheduling delta: (Target - Start - TotalPlannedTimeWithBreaks)
    // This is the fundamental time buffer/deficit built into the schedule
    if (targetCompletionTime.value && presentationStartTime.value) {
        const totalPlannedMs = totalPlannedTimeWithBreaks.value * 60 * 1000
        const schedulingDeltaMs = targetCompletionTime.value - presentationStartTime.value - totalPlannedMs
        bankedTime += schedulingDeltaMs / (60 * 1000)
    } else if (targetCompletionTime.value && !presentationStartTime.value) {
        // Before presentation starts, calculate theoretical delta from current time
        const totalPlannedMs = totalPlannedTimeWithBreaks.value * 60 * 1000
        const schedulingDeltaMs = targetCompletionTime.value - Date.now() - totalPlannedMs
        bankedTime += schedulingDeltaMs / (60 * 1000)
    }

    // 2. Dynamic banking: For completed slides, add performance delta (planned - actual)
    // Only add this if presentation has started
    if (presentationHasStarted.value) {
        for (let i = 1; i < $slidev.nav.currentPage; i++) {
            const plannedMinutes = slideTimes.value[i - 1] || 2
            const actualMinutes = (slideElapsedTimes.value[i] || 0) / 60
            const delta = plannedMinutes - actualMinutes  // positive = saved time, negative = over time
            bankedTime += delta
        }
    }

    // 3. Break performance delta: For completed breaks, add performance delta (planned - actual)
    if (presentationHasStarted.value) {
        Object.values(breakTimes.value).forEach(breakRecord => {
            if (breakRecord.completed && breakRecord.actualDurationMinutes !== undefined) {
                const plannedMinutes = breakRecord.durationMinutes
                const actualMinutes = breakRecord.actualDurationMinutes
                const delta = plannedMinutes - actualMinutes  // positive = saved time, negative = over time
                bankedTime += delta
            }
        })
    }

    // Current slide and active breaks are NOT included in banking - this shows only completed items
    // This way you can see: +10 mins banked, -5 mins on current slide = 5 mins ahead overall

    return bankedTime
})

// Breakdown components for detailed tooltip
const schedulingDeltaMinutes = computed(() => {
    if (!targetCompletionTime.value) {
        return 0
    }

    const totalPlannedMinutes = slideTimes.value.reduce((sum, slideTime) => sum + slideTime, 0)

    if (presentationStartTime.value) {
        // If presentation has started, calculate: Target - Start - TotalPlannedTime
        const totalPlannedMs = totalPlannedMinutes * 60 * 1000
        const schedulingDeltaMs = targetCompletionTime.value - presentationStartTime.value - totalPlannedMs
        return schedulingDeltaMs / (60 * 1000)
    } else {
        // If presentation hasn't started, calculate: Target - Now - TotalPlannedTime
        const totalPlannedMs = totalPlannedMinutes * 60 * 1000
        const schedulingDeltaMs = targetCompletionTime.value - Date.now() - totalPlannedMs
        return schedulingDeltaMs / (60 * 1000)
    }
})

const dynamicBankingMinutes = computed(() => {
    if (!presentationHasStarted.value) {
        return 0
    }

    let dynamicBanking = 0
    for (let i = 1; i < $slidev.nav.currentPage; i++) {
        const plannedMinutes = slideTimes.value[i - 1] || 2
        const actualMinutes = (slideElapsedTimes.value[i] || 0) / 60
        const delta = plannedMinutes - actualMinutes
        dynamicBanking += delta
    }
    return dynamicBanking
})

// Remaining time for all remaining slides (including current)
const remainingTimeMinutes = computed(() => {
    let remainingTime = 0

    // Add planned time for current slide and all future slides
    for (let i = $slidev.nav.currentPage - 1; i < slideTimes.value.length; i++) {
        remainingTime += slideTimes.value[i] || 2
    }

    // Subtract time already spent on current slide
    const currentSlideActualMinutes = currentSlideElapsed.value / 60
    remainingTime -= currentSlideActualMinutes

    return Math.max(0, remainingTime)
})

// Estimated end time
const estimatedEndTime = computed(() => {
    // We need either presentation start time or current time to calculate
    if (!presentationStartTime.value && !targetCompletionTime.value) {
        return null
    }

    if (presentationHasStarted.value && presentationStartTime.value) {
        // Presentation has started - calculate: CurrentTime + RemainingSlideTime + RemainingBreakTime
        const remainingSlideMs = remainingTimeMinutes.value * 60 * 1000

        // Calculate remaining planned break time for breaks that haven't been taken yet
        const now = new Date()
        const currentTimeMinutes = now.getHours() * 60 + now.getMinutes()

        const remainingBreakTime = breaks.value.reduce((sum, breakItem) => {
            const breakId = `${breakItem.targetTime}-${breakItem.durationMinutes}-${breakItem.label}`
            const breakRecord = breakTimes.value[breakId]

            // If break has been completed or skipped, don't include it
            if (breakRecord && (breakRecord.completed || breakRecord.skipped)) {
                return sum
            }

            // Check if break time is in the future or currently due
            const [hours, minutes] = (breakItem.targetTime || '00:00').split(':').map(Number)
            const targetTimeMinutes = hours * 60 + minutes

            if (targetTimeMinutes >= currentTimeMinutes) {
                return sum + (breakItem.durationMinutes || 0)
            }

            return sum
        }, 0)

        const remainingBreakMs = remainingBreakTime * 60 * 1000
        return new Date(currentTime.value + remainingSlideMs + remainingBreakMs)
    } else if (presentationStartTime.value) {
        // Presentation hasn't started but we have a start time - show theoretical end time
        const totalPlannedMs = totalPlannedTimeWithBreaks.value * 60 * 1000
        return new Date(presentationStartTime.value + totalPlannedMs)
    } else if (targetCompletionTime.value) {
        // No start time set, but we have a target - show theoretical end based on current time
        const totalPlannedMs = totalPlannedTimeWithBreaks.value * 60 * 1000
        return new Date(currentTime.value + totalPlannedMs)
    }

    return null
})

// Time delta between estimated end time and target completion time
// This should equal bankedTimeMinutes: EstimatedEnd - Target = Banking
const timeDeltaInfo = computed(() => {
    if (!targetCompletionTime.value || !estimatedEndTime.value) {
        return { show: false, delta: 0, formattedDelta: '' }
    }

    const deltaMs = estimatedEndTime.value.getTime() - targetCompletionTime.value
    const deltaMinutes = deltaMs / (60 * 1000)

    // This delta should equal bankedTimeMinutes (EstimatedEnd - Target = Banking)
    // Format the delta as +/- minutes, but keep precise calculation
    let formattedDelta
    if (Math.abs(deltaMinutes) < 1) {
        // Less than a minute difference
        formattedDelta = `${deltaMinutes > 0 ? '+' : '-'}${Math.abs(Math.round(deltaMinutes * 60))}s`
    } else if (Math.abs(deltaMinutes) < 60) {
        // Less than an hour
        formattedDelta = `${deltaMinutes > 0 ? '+' : '-'}${Math.abs(Math.round(deltaMinutes))}m`
    } else {
        // Hours and minutes
        const hours = Math.floor(Math.abs(deltaMinutes) / 60)
        const minutes = Math.round(Math.abs(deltaMinutes) % 60)
        formattedDelta = `${deltaMinutes > 0 ? '+' : '-'}${hours}h${minutes > 0 ? ' ' + minutes + 'm' : ''}`
    }

    return {
        show: true,
        delta: deltaMinutes, // Keep precise delta for calculations
        formattedDelta: formattedDelta
    }
})

// Add remaining breaks computed property

const remainingBreaksInfo = computed(() => {
    if (breaks.value.length === 0) {
        return { count: 0, time: 0 }
    }

    const now = new Date()
    const currentTimeMinutes = now.getHours() * 60 + now.getMinutes()

    let count = 0
    let time = 0

    breaks.value.forEach(breakItem => {
        const breakId = `${breakItem.targetTime}-${breakItem.durationMinutes}-${breakItem.label}`
        const breakRecord = breakTimes.value[breakId]

        // If break has been completed or skipped, don't count it
        if (breakRecord && (breakRecord.completed || breakRecord.skipped)) {
            return
        }

        // Check if break time is in the future or currently due
        const [hours, minutes] = (breakItem.targetTime || '00:00').split(':').map(Number)
        const targetTimeMinutes = hours * 60 + minutes

        if (targetTimeMinutes >= currentTimeMinutes) {
            count++
            time += (breakItem.durationMinutes || 0)
        }
    })

    return { count, time }
})

// Listen for storage changes
const handleStorageChange = (event) => {
    if (event.key === PRESENTATION_START_KEY) {
        presentationStartTime.value = event.newValue ? parseInt(event.newValue) : null
    } else if (event.key === TARGET_COMPLETION_KEY) {
        targetCompletionTime.value = event.newValue ? parseInt(event.newValue) : null
    } else if (event.key === SLIDE_TIMES_KEY) {
        // Reload slide elapsed times when they change
        loadSlideElapsedTimes()
    }
}

// Watch for slide changes
watch(() => $slidev.nav.currentPage, (newPage, oldPage) => {
    if (oldPage !== undefined) {
        // Save the time for the slide we're leaving (oldPage)
        const slideNum = oldPage

        // Calculate total elapsed time for the slide we're leaving
        // CRITICAL: Use the current elapsed time calculation to avoid timing jumps
        const previousStoredTime = slideElapsedTimes.value[slideNum] || 0
        let sessionTime = 0
        if (presentationHasStarted.value) {
            sessionTime = (currentTime.value - slideStartTime.value) / 1000
        }
        const totalElapsedTime = previousStoredTime + sessionTime

        // Store the final time for this slide
        slideElapsedTimes.value[slideNum] = totalElapsedTime
        localStorage.setItem(SLIDE_TIMES_KEY, JSON.stringify(slideElapsedTimes.value))
    }

    // Start timing for the new slide AFTER saving the old one
    startSlideTimer()
}, { immediate: true })

// Setup and cleanup
onMounted(() => {
    loadStoredData()
    loadSlideElapsedTimes() // Load slide elapsed times for banking calculations
    loadBreaks() // Load breaks from storage
    loadBreakTimes() // Load break times from storage
    startSlideTimer() // Initialize slide timer
    window.addEventListener('storage', handleStorageChange)

    // Update current time every second
    intervalId.value = setInterval(() => {
        currentTime.value = Date.now()
    }, 1000)
})

onUnmounted(() => {
    saveCurrentSlideTime() // Save current slide time before unmounting
    window.removeEventListener('storage', handleStorageChange)
    if (intervalId.value) {
        clearInterval(intervalId.value)
    }
})

</script>

<style scoped>
.timer-bar {
    display: contents;
}
</style>
