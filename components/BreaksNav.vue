<template>
    <button v-if="$slidev.nav.isPresenter && hasBreaks" class="slidev-icon-btn aspect-ratio-initial breaks-nav"
        :title="tooltipText" @click="handleBreakClick">
        <mdi-coffee class="slidev-icon" />
        <div class="time-container">
            <span class="break-text" :class="breakClass">{{ displayText }}</span>
        </div>
    </button>

    <!-- Break Modal -->
    <div v-if="showBreakModal" class="break-modal-overlay" @click="closeBreakModal">
        <div class="break-modal" @click.stop>
            <div class="break-content">
                <h3>{{ nextBreak?.label || 'Break Time' }}</h3>
                <h3 v-if="activeBreak">{{ activeBreak.label || 'Break Active' }}</h3>

                <div v-if="!activeBreak" class="break-start">
                    <template v-if="nextBreak?.minutesDiff >= 0">
                        <p>It's time for your scheduled break!</p>
                        <p><strong>Duration:</strong> {{ nextBreak?.durationMinutes }} minutes</p>
                        <p><strong>Scheduled for:</strong> {{ nextBreak?.targetTime }}</p>
                        <p v-if="nextBreak?.minutesDiff > 0" class="overdue-warning">
                            {{ Math.round(nextBreak.minutesDiff) }} minutes overdue
                        </p>
                    </template>
                    <template v-else>
                        <p>Upcoming break:</p>
                        <p><strong>Duration:</strong> {{ nextBreak?.durationMinutes }} minutes</p>
                        <p><strong>Scheduled for:</strong> {{ nextBreak?.targetTime }}</p>
                        <p class="countdown">{{ Math.ceil(-nextBreak.minutesDiff) }} minutes remaining</p>
                    </template>
                    <div class="break-buttons">
                        <button v-if="nextBreak?.minutesDiff >= 0" @click="skipBreak" class="skip-button">Skip
                            Break</button>
                        <button v-else @click="closeBreakModal" class="cancel-button">Close</button>
                        <button @click="startBreak" class="start-button">Start Break</button>
                    </div>
                </div>

                <div v-if="activeBreak" class="break-active">
                    <div class="break-timer">
                        <div class="timer-display">{{ formatBreakTime(breakTimeRemaining) }}</div>
                        <div class="timer-label">remaining</div>
                    </div>

                    <div class="break-progress">
                        <div class="progress-bar">
                            <div class="progress-fill" :style="{ width: breakProgress + '%' }"></div>
                        </div>
                        <p class="progress-text">{{ Math.round(breakProgress) }}% complete</p>
                    </div>

                    <div class="break-buttons">
                        <button @click="endBreakEarly" class="end-button">End Break</button>
                        <button v-if="breakTimeRemaining <= 0" @click="resumePresentation"
                            class="resume-button pulsing">Resume
                            Presentation</button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'

// Storage keys
const STORAGE_KEY_PREFIX = 'slidev-turtle-'
const BREAKS_KEY = `${STORAGE_KEY_PREFIX}breaks`
const BREAK_TIMES_KEY = `${STORAGE_KEY_PREFIX}break-times`

// Props from TimerBar
const props = defineProps({
    presentationElapsedMinutes: {
        type: Number,
        required: true
    },
    presentationHasStarted: {
        type: Boolean,
        required: true
    },
    currentTime: {
        type: Number,
        required: true
    },
    presentationStartTime: {
        type: Number,
        default: null
    }
})

// Emit break status changes to TimerBar
const emit = defineEmits(['break-status-changed'])

// Emit break status whenever break state changes
const emitBreakStatus = () => {
    const breakInfo = {
        isActive: !!activeBreak.value,
        breakStartTime: breakStartTime.value,
        breakInfo: activeBreak.value,
        timeRemaining: breakTimeRemaining.value
    }
    emit('break-status-changed', breakInfo)
}

// Reactive data
const breaks = ref([])
const breakTimes = ref({}) // Stores when breaks were actually taken
const activeBreak = ref(null)
const breakStartTime = ref(null)
const showBreakModal = ref(false)

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

// Check if any breaks are configured
const hasBreaks = computed(() => {
    return breaks.value.length > 0
})

// Find the next break with status information
const nextBreak = computed(() => {
    if (breaks.value.length === 0) {
        return null
    }

    const now = new Date()
    const currentTime = now.getHours() * 60 + now.getMinutes() // Current time in minutes since midnight

    // Find breaks that haven't been taken yet
    const availableBreaks = breaks.value.filter(breakItem => {
        const breakId = `${breakItem.targetTime}-${breakItem.durationMinutes}-${breakItem.label}`
        return !breakTimes.value[breakId] // Not yet taken
    })

    if (availableBreaks.length === 0) return null

    // Sort by target time and get the earliest
    const sortedBreaks = availableBreaks.sort((a, b) => {
        const [aHours, aMinutes] = (a.targetTime || '00:00').split(':').map(Number)
        const [bHours, bMinutes] = (b.targetTime || '00:00').split(':').map(Number)
        const aTime = aHours * 60 + aMinutes
        const bTime = bHours * 60 + bMinutes
        return aTime - bTime
    })

    const earliestBreak = sortedBreaks[0]

    // Calculate time difference
    const [hours, minutes] = (earliestBreak.targetTime || '00:00').split(':').map(Number)
    const targetTimeMinutes = hours * 60 + minutes
    const minutesDiff = currentTime - targetTimeMinutes

    // Return break with status
    return {
        ...earliestBreak,
        status: minutesDiff >= 0 ? 'ready' : 'upcoming',
        minutesDiff: minutesDiff
    }
})

// Check if break is ready (time has passed)
const isBreakReady = computed(() => {
    return nextBreak.value?.status === 'ready' && !activeBreak.value
})

// Calculate break time remaining when active
const breakTimeRemaining = computed(() => {
    if (!activeBreak.value || !breakStartTime.value) return 0

    const elapsed = (props.currentTime - breakStartTime.value) / 1000 / 60 // minutes
    return Math.max(0, activeBreak.value.durationMinutes - elapsed)
})

// Calculate break progress percentage
const breakProgress = computed(() => {
    if (!activeBreak.value || !breakStartTime.value) return 0

    const elapsed = (props.currentTime - breakStartTime.value) / 1000 / 60 // minutes
    return Math.min(100, (elapsed / activeBreak.value.durationMinutes) * 100)
})

// Display text for the break button
const displayText = computed(() => {
    if (activeBreak.value) {
        return formatBreakTime(breakTimeRemaining.value)
    } else if (nextBreak.value) {
        if (nextBreak.value.minutesDiff > 0) {
            // Show how many minutes we're past the scheduled break
            return `+${Math.round(nextBreak.value.minutesDiff)}m`
        } else {
            // Show countdown to upcoming break in minutes
            return `${Math.ceil(-nextBreak.value.minutesDiff)}m`
        }
    }
    return ''
})

// CSS class for break styling
const breakClass = computed(() => {
    const classes = []

    // Add active break styling
    if (activeBreak.value) {
        classes.push('break-active')

        // During active break, check if we're overdue
        if (breakTimeRemaining.value <= 0) {
            const overdue = Math.abs(breakTimeRemaining.value)
            if (overdue > 5 * 60) { // 5 minutes
                classes.push('break-overdue-severe')
            } else {
                classes.push('break-overdue')
            }
        }
    } else if (nextBreak.value) {
        // Not in active break, check next break status
        if (nextBreak.value.status === 'ready') {
            const overdue = Math.abs(nextBreak.value.minutesDiff)
            if (overdue > 5) {
                classes.push('break-overdue-severe')
            } else {
                classes.push('break-overdue')
            }
        } else {
            classes.push('break-upcoming')
        }
    }

    return classes
})

// Tooltip text
const tooltipText = computed(() => {
    if (activeBreak.value) {
        const remaining = formatBreakTime(breakTimeRemaining.value)
        return breakTimeRemaining.value <= 0
            ? `Break complete! Click to resume presentation`
            : `Break in progress: ${remaining} remaining | Click to manage`
    } else if (nextBreak.value) {
        const label = nextBreak.value.label || 'Break'
        const targetTime = nextBreak.value.targetTime || '00:00'

        if (nextBreak.value.minutesDiff > 0) {
            return `${label} (${nextBreak.value.durationMinutes}min) scheduled for ${targetTime} - ${Math.round(nextBreak.value.minutesDiff)} minutes overdue | Click to start or skip`
        } else {
            return `${label} (${nextBreak.value.durationMinutes}min) scheduled for ${targetTime} - ${Math.ceil(-nextBreak.value.minutesDiff)} minutes remaining | Click to view`
        }
    }
    return 'No scheduled breaks'
})

// Format time for display (MM:SS)
const formatBreakTime = (minutes) => {
    const totalSeconds = Math.max(0, minutes * 60)
    const mins = Math.floor(totalSeconds / 60)
    const secs = Math.floor(totalSeconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
}

// Handle break button click
const handleBreakClick = () => {
    if (activeBreak.value) {
        if (breakTimeRemaining.value <= 0) {
            resumePresentation()
        } else {
            showBreakModal.value = true
        }
    } else if (nextBreak.value) {
        showBreakModal.value = true
    }
}

// Start a break
const startBreak = () => {
    if (!nextBreak.value || nextBreak.value.status !== 'ready') return

    activeBreak.value = nextBreak.value
    breakStartTime.value = props.currentTime
    showBreakModal.value = false

    // Emit break status change
    emitBreakStatus()
}

// End break early
const endBreakEarly = () => {
    if (!activeBreak.value) return

    // Update the break record with actual duration
    const breakId = `${activeBreak.value.targetTime}-${activeBreak.value.durationMinutes}-${activeBreak.value.label}`
    if (breakTimes.value[breakId]) {
        const actualDuration = (props.currentTime - breakStartTime.value) / 1000 / 60
        breakTimes.value[breakId].actualDurationMinutes = actualDuration
        breakTimes.value[breakId].endTimestamp = props.currentTime
        localStorage.setItem(BREAK_TIMES_KEY, JSON.stringify(breakTimes.value))
    }

    resumePresentation()
}

// Resume presentation after break
const resumePresentation = () => {
    if (activeBreak.value) {
        // Update break record with completion info
        const breakId = `${activeBreak.value.targetTime}-${activeBreak.value.durationMinutes}-${activeBreak.value.label}`
        if (breakTimes.value[breakId]) {
            const actualDuration = (props.currentTime - breakStartTime.value) / 1000 / 60
            breakTimes.value[breakId].actualDurationMinutes = actualDuration
            breakTimes.value[breakId].endTimestamp = props.currentTime
            breakTimes.value[breakId].completed = true
            localStorage.setItem(BREAK_TIMES_KEY, JSON.stringify(breakTimes.value))
        }
    }

    activeBreak.value = null
    breakStartTime.value = null
    showBreakModal.value = false

    // Notify other components
    window.dispatchEvent(new StorageEvent('storage', {
        key: BREAK_TIMES_KEY,
        newValue: JSON.stringify(breakTimes.value)
    }))

    // Emit break status change
    emitBreakStatus()
}

// Skip the current break
const skipBreak = () => {
    if (!nextBreak.value) return

    const breakId = `${nextBreak.value.targetTime}-${nextBreak.value.durationMinutes}-${nextBreak.value.label}`
    breakTimes.value[breakId] = {
        targetTime: nextBreak.value.targetTime,
        durationMinutes: nextBreak.value.durationMinutes,
        skipped: true,
        skipTime: props.currentTime,
        label: nextBreak.value.label
    }

    localStorage.setItem(BREAK_TIMES_KEY, JSON.stringify(breakTimes.value))
    showBreakModal.value = false

    // Emit break status change (not active, but state changed)
    emitBreakStatus()
}

// Close break modal
const closeBreakModal = () => {
    showBreakModal.value = false
}

// Listen for storage changes
const handleStorageChange = (event) => {
    if (event.key === BREAKS_KEY) {
        loadBreaks()
    } else if (event.key === BREAK_TIMES_KEY) {
        loadBreakTimes()
    }
}

// Setup and cleanup
onMounted(() => {
    loadBreaks()
    loadBreakTimes()
    window.addEventListener('storage', handleStorageChange)
})

onUnmounted(() => {
    window.removeEventListener('storage', handleStorageChange)
})
</script>

<style scoped>
.breaks-nav {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    transition: all 0.3s ease;
}

/* Removed pulsing animation */

.time-container {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 0.25rem;
}

.break-text {
    font-family: 'Courier New', monospace;
    font-size: 0.75rem;
    font-weight: bold;
    min-width: 3rem;
    text-align: center;
}

.break-upcoming {
    color: #6b7280;
}

.break-overdue {
    color: #eab308;
    /* Yellow */
}

.break-overdue-severe {
    color: #ef4444;
    /* Red */
}

.break-active {
    color: #3b82f6;
}

.break-complete {
    color: #10b981;
}

/* Dark mode adjustments */
.dark .break-upcoming {
    color: #9ca3af;
}

.dark .break-overdue {
    color: #facc15;
    /* Brighter yellow for dark mode */
}

.dark .break-overdue-severe {
    color: #f87171;
    /* Lighter red for dark mode */
}

.dark .break-active {
    color: #60a5fa;
}

.dark .break-complete {
    color: #10b981;
}

/* Break Modal Styles */
.break-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    z-index: 1200;
    display: flex;
    align-items: center;
    justify-content: center;
}

.break-modal {
    background: white;
    border-radius: 12px;
    padding: 32px;
    max-width: 500px;
    width: 90%;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    transition: background-color 0.2s ease, color 0.2s ease;
}

.dark .break-modal {
    background: #2d3748;
    color: #f7fafc;
}

.break-content h3 {
    margin: 0 0 20px 0;
    font-size: 24px;
    font-weight: 600;
    color: #10b981;
    text-align: center;
}

.dark .break-content h3 {
    color: #68d391;
}

.break-start p {
    margin: 0 0 12px 0;
    text-align: center;
    font-size: 16px;
}

.overdue-warning {
    color: #ef4444;
    font-weight: bold;
}

.countdown {
    color: #6b7280;
    font-size: 1.1em;
}

.dark .overdue-warning {
    color: #f87171;
}

.dark .countdown {
    color: #9ca3af;
}

.break-active {
    text-align: center;
}

.timer-display {
    font-size: 48px;
    font-weight: bold;
    font-family: 'Courier New', monospace;
    color: #3b82f6;
    margin-bottom: 8px;
}

.dark .timer-display {
    color: #60a5fa;
}

.timer-label {
    font-size: 14px;
    color: #6b7280;
    margin-bottom: 24px;
}

.dark .timer-label {
    color: #9ca3af;
}

.break-progress {
    margin: 20px 0;
}

.progress-bar {
    width: 100%;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
}

.dark .progress-bar {
    background: #4b5563;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #10b981, #059669);
    transition: width 0.3s ease;
}

.progress-text {
    text-align: center;
    font-size: 12px;
    color: #6b7280;
    margin: 8px 0 0 0;
}

.dark .progress-text {
    color: #9ca3af;
}

.break-buttons {
    display: flex;
    gap: 12px;
    justify-content: center;
    margin-top: 24px;
}

.cancel-button,
.end-button {
    padding: 10px 20px;
    background: #f3f4f6;
    color: #374151;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
}

.cancel-button:hover,
.end-button:hover {
    background: #e5e7eb;
    transform: translateY(-1px);
}

.start-button {
    padding: 10px 20px;
    background: #10b981;
    color: white;
    border: 1px solid #059669;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
}

.start-button:hover {
    background: #059669;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
}

.resume-button {
    padding: 10px 20px;
    background: #3b82f6;
    color: white;
    border: 1px solid #2563eb;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
}

.resume-button:hover {
    background: #2563eb;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
}

.resume-button.pulsing {
    animation: gentle-pulse 1.5s ease-in-out infinite;
}

/* Dark mode button styles */
.dark .cancel-button,
.dark .end-button {
    background: #4a5568;
    color: #f7fafc;
    border-color: #718096;
}

.dark .cancel-button:hover,
.dark .end-button:hover {
    background: #718096;
}

.dark .start-button {
    background: #10b981;
    border-color: #059669;
}

.dark .start-button:hover {
    background: #059669;
}

.dark .resume-button {
    background: #3b82f6;
    border-color: #2563eb;
}

.dark .resume-button:hover {
    background: #2563eb;
}

/* Animations */
@keyframes gentle-pulse {

    0%,
    100% {
        opacity: 1;
        transform: scale(1);
    }

    50% {
        opacity: 0.8;
        transform: scale(1.05);
    }
}

/* Added styles for active break */
.break-active {
    background-color: #3b82f6 !important;
    /* Blue background */
    color: white !important;
    border-color: #2563eb !important;
}

.break-active .slidev-icon {
    color: white !important;
}

/* Break countdown color progression during active break */
.break-active.break-overdue {
    background-color: #eab308 !important;
    /* Yellow when overdue */
    border-color: #ca8a04 !important;
}

.break-active.break-overdue-severe {
    background-color: #dc2626 !important;
    /* Red when severely overdue */
    border-color: #b91c1c !important;
}
</style>
