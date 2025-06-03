<template>
    <div class="finish-area">
        <!-- Finish line icon on the left -->
        <div class="finish-line-icon">
            <emojione-monotone-flag-for-chequered-flag class="icon config-icon flag-icon" />
        </div>

        <div class="timer-labels">

            <!-- Lap timer with delta symbol inside -->
            <!-- <div class="timer-with-label">
                <div class="time-difference-display countdown-display" :class="lapTimerClass">
                    <span class="timer-symbol-inline">Δ</span>
                    {{ formattedLapTimer }}
                </div>
            </div> -->

            <!-- Target completion time banking display (only show if target is set) -->
            <div v-if="hasTargetCompletion" class="timer-with-label">
                <div class="time-difference-display countdown-display" :class="targetCompletionClass">
                    <span class="timer-symbol-inline">🏦</span>
                    {{ formattedTargetCompletion }}
                </div>
            </div>

            <!-- Target completion time display (only show if target is set) -->
            <div v-if="hasTargetCompletion" class="timer-with-label">
                <div class="counter-display target-time-display">
                    <span class="timer-symbol-inline">🎯</span>
                    {{ formattedTargetTime }}
                </div>
            </div>

            <!-- Estimated finish time with ETA text inside -->
            <div class="timer-with-label">
                <div class="time-difference-display estimated-time-display" :class="estimatedTimeClass">
                    <span class="timer-symbol-inline">⏰</span>
                    {{ formattedEstimatedFinishTime }}
                </div>
            </div>
        </div>
    </div>
</template>

<script>
export default {
    name: 'FinishArea',
    props: {
        slideTimes: {
            type: Array,
            required: true
        },
        totalTimeMinutes: {
            type: Number,
            required: true
        },
        turtleElapsedTime: {
            type: Number,
            default: 0
        },
        currentSlide: {
            type: Number,
            required: true
        },
        useSlideTimesEnabled: {
            type: Boolean,
            default: false
        },
        debugEnabled: {
            type: Boolean,
            default: false
        },
        use12HourFormat: {
            type: Boolean,
            default: false
        }
    },
    data() {
        // Get timer configuration from localStorage (same as Turtle component)
        const STORAGE_KEY_PREFIX = 'slidev-turtle-';
        const MODE_KEY = `${STORAGE_KEY_PREFIX}mode`;
        const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`;
        const TARGET_COMPLETION_KEY = `${STORAGE_KEY_PREFIX}target-completion`;

        const storedMode = localStorage.getItem(MODE_KEY) || 'incremental';
        const storedStartTime = localStorage.getItem(START_TIME_KEY);
        const storedTargetCompletion = localStorage.getItem(TARGET_COMPLETION_KEY);

        return {
            slideStartTime: Date.now(),
            currentSlideElapsed: 0,
            intervalId: null,
            // Timer configuration (same as Turtle)
            timerMode: storedMode,
            presentationStartTime: storedStartTime ? parseInt(storedStartTime) : null,
            targetCompletionTime: storedTargetCompletion ? parseInt(storedTargetCompletion) : null,
            isFutureStart: false,
            // Shared timer registry for synchronization
            sharedTimerRegistry: window.__slidevRabbitSharedTimer = window.__slidevRabbitSharedTimer || {
                intervals: new Set(),
                masterInterval: null,
                tick: 0
            }
        }
    },
    computed: {
        // Check if target completion time is set
        hasTargetCompletion() {
            return this.targetCompletionTime !== null;
        },

        // Check if presentation has started yet
        hasPresentationStarted() {
            if (this.timerMode === 'wallclock' && this.presentationStartTime) {
                const now = Date.now();
                const hasStarted = this.presentationStartTime <= now;

                if (this.debugEnabled) {
                    console.log('[FinishArea] Presentation start check:', {
                        timerMode: this.timerMode,
                        presentationStartTime: this.presentationStartTime,
                        currentTime: now,
                        hasStarted,
                        timeUntilStart: hasStarted ? 0 : (this.presentationStartTime - now) / 1000
                    });
                }

                return hasStarted;
            }
            // In incremental mode, presentation starts immediately
            return true;
        },

        // Calculate target completion time banking (time difference from target)
        targetCompletionDifferenceMinutes() {
            if (!this.hasTargetCompletion) {
                return 0;
            }

            if (!this.hasPresentationStarted) {
                // Before presentation starts: Compare total presentation length to available time window
                if (!this.presentationStartTime) {
                    // If no start time set, compare against current time + total presentation time
                    const now = Date.now();
                    const plannedFinishTime = now + (this.totalTimeMinutes * 60 * 1000);
                    const differenceMilliseconds = this.targetCompletionTime - plannedFinishTime;
                    return differenceMilliseconds / (60 * 1000);
                } else {
                    // Compare planned finish time (start + total time) against target
                    const plannedFinishTime = this.presentationStartTime + (this.totalTimeMinutes * 60 * 1000);
                    const differenceMilliseconds = this.targetCompletionTime - plannedFinishTime;
                    return differenceMilliseconds / (60 * 1000);
                }
            } else {
                // During presentation: Calculate estimated finish time based on current progress
                const etaTimestamp = this.estimatedFinishTimeMinutes;
                const differenceMilliseconds = this.targetCompletionTime - etaTimestamp;
                const differenceMinutes = differenceMilliseconds / (60 * 1000);

                if (this.debugEnabled) {
                    console.log('[FinishArea] Target completion calculation:', {
                        targetCompletionTime: new Date(this.targetCompletionTime).toLocaleTimeString(),
                        etaTimestamp: new Date(etaTimestamp).toLocaleTimeString(),
                        differenceMinutes: differenceMinutes,
                        calculation: `${new Date(this.targetCompletionTime).toLocaleTimeString()} - ${new Date(etaTimestamp).toLocaleTimeString()} = ${differenceMinutes.toFixed(2)}m`
                    });
                }

                return differenceMinutes;
            }
        },

        // Format target completion time (always shows the actual target time)
        formattedTargetTime() {
            if (!this.hasTargetCompletion) {
                return '';
            }

            const targetDate = new Date(this.targetCompletionTime);
            const hours = targetDate.getHours();
            const minutes = targetDate.getMinutes();
            const seconds = targetDate.getSeconds();

            if (this.use12HourFormat) {
                const displayHours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                const ampm = hours >= 12 ? 'PM' : 'AM';
                return `${displayHours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${ampm}`;
            } else {
                return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            }
        },

        // Format target completion time banking for display (always shows difference)
        formattedTargetCompletion() {
            if (!this.hasTargetCompletion) {
                return '';
            }

            // Always show time banking (difference from target)
            const diffMinutes = Math.abs(this.targetCompletionDifferenceMinutes);
            const hours = Math.floor(diffMinutes / 60);
            const minutes = Math.floor(diffMinutes % 60);
            const seconds = Math.floor((diffMinutes % 1) * 60);

            const sign = this.targetCompletionDifferenceMinutes >= 0 ? '+' : '-';

            return `${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        },

        // CSS class for target completion styling
        targetCompletionClass() {
            if (!this.hasTargetCompletion) {
                return '';
            }

            const diffMinutes = this.targetCompletionDifferenceMinutes;

            if (diffMinutes < -5) {
                return 'time-behind'; // Red when more than 5 minutes over target
            } else if (diffMinutes < 0) {
                return 'time-warning'; // Yellow when slightly over target
            } else {
                return 'time-ahead'; // Green when on or under target
            }
        },

        // Format total time for display
        formattedTotalTime() {
            const totalMinutes = this.totalTimeMinutes;
            const hours = Math.floor(totalMinutes / 60);
            const minutes = Math.floor(totalMinutes % 60);
            const seconds = Math.floor((totalMinutes % 1) * 60);

            return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        },

        // Calculate lap timer (time difference between rabbit and turtle)
        timeDifferenceMinutes() {
            if (!this.currentSlide) return 0;

            // Don't calculate delta if presentation hasn't started yet
            if (!this.hasPresentationStarted) {
                if (this.debugEnabled) {
                    console.log('[FinishArea] Presentation not started - delta timer shows 0');
                }
                return 0;
            }

            // Calculate where rabbit will be after completing the current slide (using full planned time)
            let rabbitFutureMinutes;

            if (this.useSlideTimesEnabled && this.slideTimes && this.slideTimes.length > 0) {
                // Time-based: cumulative time up to current slide + full planned time for current slide
                let cumulativeTime = 0;

                // Add time from completed slides
                for (let i = 0; i < this.currentSlide - 1; i++) {
                    const numberTime = Number(this.slideTimes[i]);
                    cumulativeTime += !isNaN(numberTime) ? numberTime : 0;
                }

                // Add the FULL planned time for current slide (not elapsed time)
                const currentSlideTimeMinutes = Number(this.slideTimes[this.currentSlide - 1]) || 2;
                rabbitFutureMinutes = cumulativeTime + currentSlideTimeMinutes;
            } else {
                // Slide-count-based: calculate equivalent time position after current slide
                const total = this.slideTimes.length || 10; // fallback
                const slideProgressRatio = this.currentSlide / (total - 1);
                rabbitFutureMinutes = slideProgressRatio * this.totalTimeMinutes;
            }

            // Calculate where turtle will be when we finish the current slide
            const currentSlideElapsedMinutes = this.currentSlideElapsed / 60;
            const currentSlideTimeMinutes = Number(this.slideTimes[this.currentSlide - 1]) || 2;
            const remainingSlideTimeMinutes = Math.max(0, currentSlideTimeMinutes - currentSlideElapsedMinutes);

            // Turtle's current position + time remaining on this slide = where turtle will be when slide is done
            const turtleCurrentMinutes = this.turtleElapsedTime / 60;
            const turtleFutureMinutes = turtleCurrentMinutes + remainingSlideTimeMinutes;

            if (this.debugEnabled) {
                console.log('[FinishArea] Lap timer calculation:', {
                    currentSlide: this.currentSlide,
                    presentationStarted: this.hasPresentationStarted,
                    rabbitFutureMinutes,
                    turtleCurrentMinutes,
                    currentSlideElapsedMinutes,
                    currentSlideTimeMinutes,
                    remainingSlideTimeMinutes,
                    turtleFutureMinutes,
                    difference: rabbitFutureMinutes - turtleFutureMinutes
                });
            }

            return rabbitFutureMinutes - turtleFutureMinutes;
        },

        // Format lap timer for display
        formattedLapTimer() {
            // If presentation hasn't started, show 00:00:00
            if (!this.hasPresentationStarted) {
                return "+00:00:00";
            }

            const diffMinutes = Math.abs(this.timeDifferenceMinutes);
            const hours = Math.floor(diffMinutes / 60);
            const minutes = Math.floor(diffMinutes % 60);
            const seconds = Math.floor((diffMinutes % 1) * 60);

            const sign = this.timeDifferenceMinutes >= 0 ? '+' : '-';

            return `${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        },

        // CSS class for lap timer styling
        lapTimerClass() {
            // If presentation hasn't started, show as neutral/ahead
            if (!this.hasPresentationStarted) {
                return 'time-ahead';
            }

            if (this.timeDifferenceMinutes < 0) {
                return 'time-behind'; // Red when turtle is ahead
            } else if (this.timeDifferenceMinutes < 1) {
                return 'time-warning'; // Yellow when close to turtle
            } else {
                return 'time-ahead'; // Green when ahead of turtle
            }
        },

        // Calculate estimated finish time based on current pace
        estimatedFinishTimeMinutes() {
            // Calculate the estimated finish time as a wall-clock time
            // ETA = Presentation start time + sum of slide times - delta

            if (!this.presentationStartTime) {
                // Fallback: if no start time, show current time + remaining time
                const now = Date.now();
                const turtleCurrentMinutes = this.turtleElapsedTime / 60;
                const remainingMinutes = this.totalTimeMinutes - turtleCurrentMinutes;
                return now + (remainingMinutes * 60 * 1000); // Return timestamp
            }

            // Calculate the delta (difference between rabbit and turtle)
            const deltaMinutes = this.timeDifferenceMinutes;

            // ETA = Start time + Total planned time - Delta
            // When delta is negative (behind), subtracting a negative pushes ETA later
            // When delta is positive (ahead), subtracting a positive makes ETA earlier
            const etaTimestamp = this.presentationStartTime + (this.totalTimeMinutes * 60 * 1000) - (deltaMinutes * 60 * 1000);

            if (this.debugEnabled) {
                console.log('[FinishArea] ETA calculation:', {
                    presentationStartTime: new Date(this.presentationStartTime).toLocaleTimeString(),
                    totalTimeMinutes: this.totalTimeMinutes,
                    deltaMinutes: deltaMinutes,
                    etaTimestamp: new Date(etaTimestamp).toLocaleTimeString(),
                    calculation: `${new Date(this.presentationStartTime).toLocaleTimeString()} + ${this.totalTimeMinutes}m - ${deltaMinutes.toFixed(2)}m = ${new Date(etaTimestamp).toLocaleTimeString()}`
                });
            }

            return etaTimestamp;
        },

        // Format estimated finish time for display
        formattedEstimatedFinishTime() {
            const etaTimestamp = this.estimatedFinishTimeMinutes; // This is now a timestamp
            const etaDate = new Date(etaTimestamp);

            const hours = etaDate.getHours();
            const minutes = etaDate.getMinutes();
            const seconds = etaDate.getSeconds();

            if (this.use12HourFormat) {
                // 12-hour format with AM/PM
                const displayHours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                const ampm = hours >= 12 ? 'PM' : 'AM';
                return `${displayHours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${ampm}`;
            } else {
                // 24-hour format
                return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            }
        },

        // CSS class for estimated finish time styling
        estimatedTimeClass() {
            const etaTimestamp = this.estimatedFinishTimeMinutes; // This is now a timestamp

            // If we have a target completion time, use that for comparison
            if (this.hasTargetCompletion) {
                const deltaMilliseconds = etaTimestamp - this.targetCompletionTime;
                const deltaMinutes = deltaMilliseconds / (60 * 1000);

                if (deltaMinutes > 10) { // More than 10 minutes over target
                    return 'time-behind'; // Red when significantly over target
                } else if (deltaMinutes > 0) {
                    return 'time-warning'; // Yellow when slightly over target
                } else {
                    return 'time-ahead'; // Green when on or under target
                }
            } else {
                // Fallback: compare with planned finish time
                const plannedFinishTimestamp = this.presentationStartTime + (this.totalTimeMinutes * 60 * 1000);
                const deltaMilliseconds = etaTimestamp - plannedFinishTimestamp;
                const deltaMinutes = deltaMilliseconds / (60 * 1000);

                if (deltaMinutes > this.totalTimeMinutes * 0.1) { // More than 10% over planned time
                    return 'time-behind'; // Red when significantly over planned time
                } else if (deltaMinutes > 0) {
                    return 'time-warning'; // Yellow when slightly over planned time
                } else {
                    return 'time-ahead'; // Green when on or under planned time
                }
            }
        }
    },
    methods: {
        // Update slide elapsed time for lap timer calculation
        updateSlideElapsed() {
            const now = Date.now();

            // Update presentation start status
            if (this.timerMode === 'wallclock' && this.presentationStartTime) {
                this.isFutureStart = this.presentationStartTime > now;
            } else {
                this.isFutureStart = false;
            }

            // Only update slide time if presentation has started
            if (this.hasPresentationStarted) {
                this.currentSlideElapsed = (now - this.slideStartTime) / 1000;
            } else {
                this.currentSlideElapsed = 0;
            }
        },

        // Reset slide timer when slide changes
        resetSlideTimer() {
            this.slideStartTime = Date.now();
            this.currentSlideElapsed = 0;

            if (this.debugEnabled) {
                console.log(`[FinishArea] Slide timer reset for slide ${this.currentSlide}`);
            }
        }
    },
    watch: {
        // Watch for slide changes to reset the timer
        currentSlide: {
            handler() {
                if (this.currentSlide) {
                    this.resetSlideTimer();
                }
            },
            immediate: true
        }
    },
    mounted() {
        // Initialize slide timer
        this.resetSlideTimer();

        // Register with shared timer system for synchronization
        const updateFn = () => {
            this.updateSlideElapsed();
        };

        this.sharedTimerRegistry.intervals.add(updateFn);

        // Create master interval if it doesn't exist
        if (!this.sharedTimerRegistry.masterInterval) {
            this.sharedTimerRegistry.masterInterval = setInterval(() => {
                this.sharedTimerRegistry.tick++;
                this.sharedTimerRegistry.intervals.forEach(fn => fn());
            }, 1000);
        }

        // Store reference for cleanup
        this.intervalId = updateFn;
    },
    beforeUnmount() {
        // Clean up from shared timer registry
        if (this.intervalId) {
            this.sharedTimerRegistry.intervals.delete(this.intervalId);
        }

        // Clean up master interval if no more components
        if (this.sharedTimerRegistry.intervals.size === 0 && this.sharedTimerRegistry.masterInterval) {
            clearInterval(this.sharedTimerRegistry.masterInterval);
            this.sharedTimerRegistry.masterInterval = null;
        }
    }
}
</script>