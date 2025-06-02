<template>
  <div class="lane-item" :style="positionStyle">
    <emojione-monotone-rabbit class="icon" />
    <div class="counter-display" :class="[isLatter ? 'float-left' : 'float-right']" :style="{
      display: showSlideNum ? 'flex' : 'none'
    }">
      {{ props.current }} / {{ total }}
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
  }
});

// Add a computed property that checks for both naming conventions
const useTimeBasedPositioning = computed(() => {
  const configEnabled = $slidev.configs.rabbit?.useSlideTimes === true;
  const propEnabled = props.useSlideTimesEnabled === true;

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
        console.log(`[Rabbit] Time-based position: ${percentage.toFixed(2)}%`);
      }
    }
  }

  if (!percentage) {
    // Default: Use slide-count-based positioning (as percentage)
    percentage = ((props.current - 1) / (total - 1)) * 100;
    console.log(`[Rabbit] Slide-count-based position: ${percentage.toFixed(2)}% (Slide ${props.current} of ${total})`);
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

  console.log(`[Rabbit] Position: ${percent}%, isLatter: ${isLatter.value}`);

  if (isLatter.value) {
    // In the latter half, use transform to align right edge with position
    console.log(`[Rabbit] Using transform for right-edge alignment at ${percent}%`);
    return {
      left: percent + '%',
      transform: 'translateX(-100%)',
      right: 'auto'
    };
  } else {
    // In the first half, use normal left positioning
    console.log(`[Rabbit] Using left positioning: ${percent}%`);
    return {
      left: percent + '%',
      transform: 'none',
      right: 'auto'
    };
  }
});

// Update isLatter whenever the position changes
watch(positionPercent, (newPercent) => {
  const wasLatter = isLatter.value;
  isLatter.value = newPercent > 50; // Past halfway point

  console.log(`[Rabbit] Position changed: ${newPercent}%, isLatter: ${wasLatter} -> ${isLatter.value}`);
}, { immediate: true });
</script>
