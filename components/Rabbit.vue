<template>
  <div class="lane-item" :style="positionStyle">
    <emojione-monotone-rabbit class="icon" />
    <!-- Removed the time difference display - now in Flag component -->
    <!-- New slide countdown display - only show if enabled -->
    <div v-if="showSlideCountdown" class="time-difference-display"
      :class="[isLatter ? 'float-left' : 'float-right', slideCountdownClass]">
      {{ formattedSlideCountdown }}
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';

const showSlideNum = $slidev.configs?.rabbit?.slideNum ?? false;
const showSlideCountdown = $slidev.configs?.rabbit?.showSlideCountdown ?? false;
const pauseSlideCountdownUntilStart = $slidev.configs?.rabbit?.pauseSlideCountdownUntilStart ?? true;
const total = $slidev.nav.total;

// Track whether we're on the latter half of the screen
const isLatter = ref(false);

// Track slide timing
const slideStartTime = ref(Date.now());
const currentSlideElapsed = ref(0);
const intervalId = ref(null);

// Shared timer registry for synchronization with Turtle
const sharedTimerRegistry = window.__slidevRabbitSharedTimer = window.__slidevRabbitSharedTimer || {
  intervals: new Set(),
  masterInterval: null,
  tick: 0
};

// Track turtle position when slide starts (for lap timer calculation)
const turtlePositionAtSlideStart = ref(0);

// Track presentation timing (same logic as Turtle)
const STORAGE_KEY_PREFIX = 'slidev-turtle-';
const MODE_KEY = `${STORAGE_KEY_PREFIX}mode`;
const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`;

const timerMode = ref(localStorage.getItem(MODE_KEY) || 'incremental');
const storedStartTime = localStorage.getItem(START_TIME_KEY);
const presentationStartTime = ref(storedStartTime ? parseInt(storedStartTime) : null);
const isFutureStart = ref(false);

const props = defineProps({
  current: Number,
  slideTimes: {
    type: Array,
    default: () => []
  },
  useSlideTimesEnabled: {
    type: Boolean,
    default: false
  },
  turtleElapsedTime: {
    type: Number,
    default: 0
  },
  totalTimeMinutes: {
    type: Number,
    default: 10
  },
  debugEnabled: {
    type: Boolean,
    default: false
  }
});

// Add a computed property that checks for both naming conventions
const useTimeBasedPositioning = computed(() => {
  const configEnabled = $slidev.configs.rabbit?.useSlideTimes === true;
  const propEnabled = props.useSlideTimesEnabled === true;

  if (props.debugEnabled) {
    // Log all Slidev nav and slide data for debugging
    console.log('[Rabbit] Full Slidev context:', {
      config: $slidev.configs,
      nav: $slidev.nav,
      currentPage: $slidev.nav.currentPage,
      currentLayout: $slidev.nav.currentLayout,
      currentComponent: $slidev.nav.currentComponent,
      slides: $slidev.nav.slides
    });

    console.log('[Rabbit] Component props:', {
      current: props.current,
      slideTimes: props.slideTimes,
      useSlideTimesEnabled: props.useSlideTimesEnabled,
      propsRaw: props
    });

    console.log('[Rabbit] Time-based positioning detection:', {
      configEnabled,
      propEnabled,
      rabbitConfig: $slidev.configs.rabbit,
      slideTimes: props.slideTimes
    });
  }

  return configEnabled || propEnabled;
});

// Calculate position as a percentage (0-100%)
const positionPercent = computed(() => {
  if (props.current === 1 || total === 1) {
    return 0;
  }

  let percentage;

  // Use time-based positioning if enabled and we have slide times
  if (useTimeBasedPositioning.value && props.slideTimes && props.slideTimes.length > 0) {
    // Check for positive times more explicitly
    const hasPositiveTime = props.slideTimes.some(time => {
      const numberTime = Number(time);
      return !isNaN(numberTime) && numberTime > 0;
    });

    if (hasPositiveTime) {
      // Calculate cumulative time up to the current slide
      let cumulativeTime = 0;
      let totalTime = 0;

      // Calculate total time of all slides
      totalTime = props.slideTimes.reduce((sum, time) => {
        const numberTime = Number(time);
        return sum + (!isNaN(numberTime) ? numberTime : 0);
      }, 0);

      // Calculate time elapsed up to (but NOT including) the current slide
      for (let i = 0; i < props.current - 1; i++) {
        const numberTime = Number(props.slideTimes[i]);
        cumulativeTime += !isNaN(numberTime) ? numberTime : 0;
      }

      if (totalTime > 0) {
        // Position based on proportion of elapsed time to total time (as percentage)
        percentage = (cumulativeTime / totalTime) * 100;

        // Get current slide's individual time
        const currentSlideTime = Number(props.slideTimes[props.current - 1]);
        const cumulativeTimeUpToCurrent = cumulativeTime - currentSlideTime;

        // Enhanced logging with detailed math
        if (props.debugEnabled) {
          console.log(`[Rabbit] Time-based positioning calculation:`, {
            currentSlide: props.current,
            totalSlides: total,
            slideTimes: props.slideTimes,
            slideTimesWithIndex: props.slideTimes.map((time, index) => ({
              slideIndex: index + 1,
              slideTime: time,
              hasSlideTimeValue: time !== undefined && time !== null,
              isCurrentSlide: (index + 1) === props.current
            })),
            currentSlideTimeMinutes: currentSlideTime,
            cumulativeTimeUpToCurrentMinutes: cumulativeTimeUpToCurrent,
            totalCumulativeTimeMinutes: cumulativeTime,
            totalPresentationTimeMinutes: totalTime,
            timeBreakdown: {
              upToCurrent: `${cumulativeTimeUpToCurrent} minutes (slides 1-${props.current - 1})`,
              currentSlide: `${currentSlideTime} minutes (slide ${props.current})`,
              total: `${cumulativeTime} minutes (slides 1-${props.current})`
            },
            timeDeltaRatio: `${cumulativeTime}/${totalTime} = ${(cumulativeTime / totalTime).toFixed(4)}`,
            finalPercentage: percentage.toFixed(2) + '%',
            math: `(${cumulativeTime} / ${totalTime}) * 100 = ${percentage.toFixed(2)}%`,
            calculation: `(${cumulativeTimeUpToCurrent} + ${currentSlideTime}) / ${totalTime} * 100 = ${percentage.toFixed(2)}%`
          });
        }
      }
    }
  }

  if (!percentage) {
    // Default: Use slide-count-based positioning (as percentage)
    percentage = ((props.current - 1) / (total - 1)) * 100;
    if (props.debugEnabled) {
      console.log(`[Rabbit] Slide-count-based positioning calculation:`, {
        currentSlide: props.current,
        totalSlides: total,
        slideProgressRatio: `(${props.current - 1})/(${total - 1}) = ${((props.current - 1) / (total - 1)).toFixed(4)}`,
        finalPercentage: percentage.toFixed(2) + '%',
        math: `((${props.current} - 1) / (${total} - 1)) * 100 = ${percentage.toFixed(2)}%`
      });
    }
  }

  // Ensure percentage stays within 0-100%
  if (percentage > 100) {
    percentage = 100;
  }

  return percentage;
});

// Dynamic positioning style that uses transform for right-edge alignment
const positionStyle = computed(() => {
  const percent = positionPercent.value;

  if (props.debugEnabled) {
    console.log(`[Rabbit] Position: ${percent}%, isLatter: ${isLatter.value}`);
  }

  // Always center the rabbit icon on the tick mark
  if (props.debugEnabled) {
    console.log(`[Rabbit] Using centered positioning at ${percent}%`);
  }

  if (isLatter.value) {
    // In the latter half, start from right-edge alignment and adjust to center the icon
    return {
      left: percent + '%',
      transform: 'translateX(calc(-100% + 10px))', // Right-align container, then shift icon center to tick mark
      right: 'auto'
    };
  } else {
    // In the first half, shift left from left-edge to center the icon
    return {
      left: percent + '%',
      transform: 'translateX(-10px)', // Center the rabbit icon (assuming ~20px icon width)
      right: 'auto'
    };
  }
});

// Update isLatter whenever the position changes
watch(positionPercent, (newPercent) => {
  const wasLatter = isLatter.value;
  isLatter.value = newPercent > 50; // Past halfway point

  if (props.debugEnabled) {
    console.log(`[Rabbit] Position changed: ${newPercent}%, isLatter: ${wasLatter} -> ${isLatter.value}`);
  }
}, { immediate: true });

// Calculate the rabbit's current time position in minutes
const rabbitTimePosition = computed(() => {
  if (useTimeBasedPositioning.value && props.slideTimes && props.slideTimes.length > 0) {
    // Calculate cumulative time up to (but NOT including) current slide
    let cumulativeTime = 0;
    for (let i = 0; i < props.current - 1; i++) {
      const numberTime = Number(props.slideTimes[i]);
      cumulativeTime += !isNaN(numberTime) ? numberTime : 0;
    }
    return cumulativeTime;
  } else {
    // Slide-count-based: calculate equivalent time position
    const slideProgressRatio = (props.current - 1) / (total - 1);
    return slideProgressRatio * props.totalTimeMinutes;
  }
});

// Get current slide time in minutes
const currentSlideTimeMinutes = computed(() => {
  if (props.slideTimes && props.slideTimes.length > 0 && props.current <= props.slideTimes.length) {
    const slideTime = Number(props.slideTimes[props.current - 1]);
    return !isNaN(slideTime) ? slideTime : 2; // Default to 2 minutes if invalid
  }
  return 2; // Default slide time
});

// Calculate slide remaining time in seconds
const slideRemainingSeconds = computed(() => {
  const slideTimeSeconds = currentSlideTimeMinutes.value * 60;
  return slideTimeSeconds - currentSlideElapsed.value;
});

// Format slide countdown for display
const formattedSlideCountdown = computed(() => {
  // Helper function to format time based on 12/24 hour preference
  const formatTime = (totalSeconds) => {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = Math.floor(totalSeconds % 60);

    // 24-hour format
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  };

  // If presentation hasn't started, show full slide time as countdown
  if (isFutureStart.value) {
    const slideTimeSeconds = currentSlideTimeMinutes.value * 60;
    return formatTime(slideTimeSeconds);
  }

  // Normal countdown logic
  const remainingSeconds = Math.abs(slideRemainingSeconds.value);
  const sign = slideRemainingSeconds.value < 0 ? '-' : '';

  return `${sign}${formatTime(remainingSeconds)}`;
});

// CSS class for slide countdown styling
const slideCountdownClass = computed(() => {
  // If presentation hasn't started, show as ahead (green)
  if (isFutureStart.value) {
    return 'time-ahead';
  }

  // Normal styling logic
  if (slideRemainingSeconds.value < 0) {
    return 'time-behind'; // Red when over slide time
  } else if (slideRemainingSeconds.value < 60) {
    return 'time-warning'; // Yellow when less than 1 minute left
  } else {
    return 'time-ahead'; // Green when plenty of time left
  }
});

// Function to update slide elapsed time
const updateSlideElapsed = () => {
  const now = Date.now();

  // Check if presentation hasn't started yet (same logic as Turtle) - only if pause feature is enabled
  if (pauseSlideCountdownUntilStart && timerMode.value === 'wallclock' && presentationStartTime.value) {
    if (presentationStartTime.value > now) {
      // Presentation hasn't started yet - don't count slide time
      isFutureStart.value = true;
      currentSlideElapsed.value = 0;
      return;
    } else {
      // Presentation has started
      isFutureStart.value = false;
    }
  } else {
    isFutureStart.value = false;
  }

  // Only update slide elapsed time if presentation has started (or if pause feature is disabled)
  if (!isFutureStart.value) {
    currentSlideElapsed.value = (now - slideStartTime.value) / 1000;
  }
};

// Reset slide timer when slide changes
const resetSlideTimer = () => {
  slideStartTime.value = Date.now();
  currentSlideElapsed.value = 0;
  turtlePositionAtSlideStart.value = props.turtleElapsedTime / 60; // Convert seconds to minutes

  if (props.debugEnabled) {
    console.log(`[Rabbit] Slide timer reset for slide ${props.current}, allocated time: ${currentSlideTimeMinutes.value} minutes`);
  }
};

// Watch for slide changes
watch(() => props.current, () => {
  resetSlideTimer();
}, { immediate: true });

// Lifecycle hooks
onMounted(() => {
  resetSlideTimer();

  // Register with shared timer system instead of creating own interval
  const updateFn = () => {
    updateSlideElapsed();
  };

  sharedTimerRegistry.intervals.add(updateFn);

  // Create master interval if it doesn't exist
  if (!sharedTimerRegistry.masterInterval) {
    sharedTimerRegistry.masterInterval = setInterval(() => {
      sharedTimerRegistry.tick++;
      sharedTimerRegistry.intervals.forEach(fn => fn());
    }, 1000);
  }

  // Store reference for cleanup
  intervalId.value = updateFn;
});

onUnmounted(() => {
  // Clean up from shared timer registry
  if (intervalId.value) {
    sharedTimerRegistry.intervals.delete(intervalId.value);
  }

  // Clean up master interval if no more components
  if (sharedTimerRegistry.intervals.size === 0 && sharedTimerRegistry.masterInterval) {
    clearInterval(sharedTimerRegistry.masterInterval);
    sharedTimerRegistry.masterInterval = null;
  }
});
</script>
