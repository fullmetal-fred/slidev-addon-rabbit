<template>
  <div class="lane-item" :style="positionStyle">
    <emojione-monotone-rabbit class="icon" />
    <div class="time-difference-display" :class="[isLatter ? 'float-left' : 'float-right', timeDifferenceClass]">
      {{ formattedTimeDifference }}
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';

const showSlideNum = $slidev.configs?.rabbit?.slideNum ?? false;
const total = $slidev.nav.total;

// Track whether we're on the latter half of the screen
const isLatter = ref(false);

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

      // Calculate time elapsed up to AND INCLUDING the current slide
      for (let i = 0; i < props.current; i++) {
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

  // Special handling for start position (0% or slide 1)
  if (percent <= 0 || props.current === 1) {
    if (props.debugEnabled) {
      console.log(`[Rabbit] Using left-align for start position`);
    }
    return {
      left: '0%',
      transform: 'none', // Left-align with the start
      right: 'auto'
    };
  }

  // Special handling for end position (100% or last slide)
  if (percent >= 100 || props.current === total) {
    if (props.debugEnabled) {
      console.log(`[Rabbit] Using right-align for end position`);
    }
    return {
      left: '100%',
      transform: 'translateX(-100%)', // Right-align with the end
      right: 'auto'
    };
  }

  // Middle positions - center the rabbit icon on the tick mark
  if (props.debugEnabled) {
    console.log(`[Rabbit] Using centered positioning at ${percent}% (middle position)`);
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
    // Calculate cumulative time up to current slide (including current slide)
    let cumulativeTime = 0;
    for (let i = 0; i < props.current; i++) {
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

// Calculate time difference (rabbit time - turtle time)
const timeDifferenceMinutes = computed(() => {
  const rabbitMinutes = rabbitTimePosition.value;
  const turtleMinutes = props.turtleElapsedTime / 60; // Convert seconds to minutes
  return rabbitMinutes - turtleMinutes;
});

// Format the time difference for display
const formattedTimeDifference = computed(() => {
  const diffMinutes = Math.abs(timeDifferenceMinutes.value);
  const hours = Math.floor(diffMinutes / 60);
  const minutes = Math.floor(diffMinutes % 60);
  const seconds = Math.floor((diffMinutes % 1) * 60);

  const sign = timeDifferenceMinutes.value >= 0 ? '+' : '-';

  // Always use hh:mm:ss format
  return `${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
});

// CSS class for styling based on time difference
const timeDifferenceClass = computed(() => {
  if (timeDifferenceMinutes.value < 0) {
    return 'time-behind'; // Red when turtle is ahead
  } else if (timeDifferenceMinutes.value < 1) {
    return 'time-warning'; // Yellow when close to turtle
  } else {
    return 'time-ahead'; // Green when ahead of turtle
  }
});
</script>
