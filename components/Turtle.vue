<template>
  <div class="lane-item" :style="positionStyle">
    <emojione-monotone-turtle class="icon" />
    <div v-if="showTimerDisplay" class="counter-display" :class="[isLatter ? 'float-left' : 'float-right']">
      <template v-if="isFutureStart">
        -{{ formattedCountdown }}
      </template>
      <template v-else>
        {{ formattedElapsedTime }}
      </template>
    </div>
  </div>
</template>

<script>
const STORAGE_KEY_PREFIX = 'slidev-turtle-';
const MODE_KEY = `${STORAGE_KEY_PREFIX}mode`;
const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`;

export default {
  props: {
    current: Number,
    totalTime: {
      type: Number,
      default: 10
    }
  },
  data() {
    const storedMode = localStorage.getItem(MODE_KEY) || 'incremental';
    const storedStartTime = localStorage.getItem(START_TIME_KEY);

    return {
      positionPercent: 0,
      lastLoggedPosition: -1, // Track last logged position to avoid spam
      intervalId: null,
      timerMode: storedMode,
      startTime: storedStartTime ? parseInt(storedStartTime) : null,
      incrementalStart: storedStartTime ? parseInt(storedStartTime) : Date.now(),
      showTimerDisplay: true,
      elapsedTime: 0,
      countdown: 0,
      isFutureStart: false
    }
  },
  computed: {
    // Determine if the turtle is in the latter half of the screen
    isLatter() {
      return this.positionPercent > 50;
    },

    // Dynamic positioning style that uses transform for right-edge alignment
    positionStyle() {
      const percent = this.positionPercent;

      if (this.isLatter) {
        // In the latter half, use transform to align right edge with position
        return {
          left: percent + '%',
          transform: 'translateX(-100%)',
          right: 'auto'
        };
      } else {
        // In the first half, use normal left positioning
        return {
          left: percent + '%',
          transform: 'none',
          right: 'auto'
        };
      }
    },

    // Format elapsed time for display (hours:minutes:seconds if hours > 0, otherwise minutes:seconds)
    formattedElapsedTime() {
      const hours = Math.floor(this.elapsedTime / 3600);
      const minutes = Math.floor((this.elapsedTime % 3600) / 60);
      const seconds = Math.floor(this.elapsedTime % 60);

      if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
      } else {
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
      }
    },
    // Format countdown for future start times (hours:minutes:seconds if hours > 0, otherwise minutes:seconds)
    formattedCountdown() {
      if (this.countdown <= 0) return "0:00";

      const hours = Math.floor(this.countdown / 3600);
      const minutes = Math.floor((this.countdown % 3600) / 60);
      const seconds = Math.floor(this.countdown % 60);

      if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
      } else {
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
      }
    }
  },
  watch: {
    totalTime: {
      handler() {
        // Recalculate position when totalTime changes
        this.updateTurtlePosition();
      },
      immediate: true
    }
  },
  mounted() {
    // Initialize the turtle position on component mount
    this.initializeTurtle();

    // Set up the interval to update position
    this.intervalId = setInterval(() => {
      this.updateTurtlePosition();
    }, 100); // update per 100ms
  },
  beforeUnmount() {
    // Clean up interval when component unmounts
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  },
  methods: {
    initializeTurtle() {
      if (this.timerMode === 'incremental') {
        // In incremental mode, start counting from the stored start time or now
        this.updateTurtlePosition();
      } else if (this.timerMode === 'wallclock' && this.startTime) {
        // In wall clock mode, calculate position based on start time
        this.updateTurtlePosition();
      } else {
        // Default case - start at 0
        this.positionPercent = 0;
      }
    },
    updateTurtlePosition() {
      const now = Date.now();
      let progressPercent = 0;

      if (this.timerMode === 'incremental') {
        // Incremental mode: progress since start time
        this.elapsedTime = (now - this.incrementalStart) / 1000;
        const totalTimeSeconds = this.totalTime * 60;
        const progress = Math.min(this.elapsedTime / totalTimeSeconds, 1);
        progressPercent = progress * 100;
      }
      else if (this.timerMode === 'wallclock' && this.startTime) {
        // Check if start time is in the future
        if (this.startTime > now) {
          // Calculate countdown
          this.countdown = (this.startTime - now) / 1000;
          this.isFutureStart = true;
          progressPercent = 0; // Keep at starting position
        } else {
          // Start time has passed, calculate normal position
          this.isFutureStart = false;
          this.elapsedTime = (now - this.startTime) / 1000;
          const totalTimeSeconds = this.totalTime * 60;
          const progress = Math.min(this.elapsedTime / totalTimeSeconds, 1);
          progressPercent = progress * 100;
        }
      }

      // Ensure percentage stays within 0-100%
      if (progressPercent > 100) {
        progressPercent = 100;
      }

      // Only log if position has changed significantly (avoid spam)
      const roundedPercent = Math.round(progressPercent * 10) / 10; // Round to 1 decimal place
      if (Math.abs(roundedPercent - this.lastLoggedPosition) >= 0.1) {
        console.log(`[Turtle] Position updated: ${this.lastLoggedPosition}% -> ${roundedPercent}%`);
        this.lastLoggedPosition = roundedPercent;
      }

      this.positionPercent = progressPercent;
    }
  }
};
</script>
