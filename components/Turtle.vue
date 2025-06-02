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
  emits: ['elapsed-time-update'],
  props: {
    current: Number,
    totalTime: {
      type: Number,
      default: 10
    },
    debugEnabled: {
      type: Boolean,
      default: false
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
      isFutureStart: false,
      sharedTimerRegistry: window.__slidevRabbitSharedTimer = window.__slidevRabbitSharedTimer || {
        intervals: new Set(),
        masterInterval: null,
        tick: 0
      }
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

      // Always center on tick marks
      if (this.isLatter) {
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
          transform: 'translateX(-10px)', // Center the turtle icon (assuming ~20px icon width)
          right: 'auto'
        };
      }
    },

    // Format elapsed time for display (always use hh:mm:ss format)
    formattedElapsedTime() {
      const hours = Math.floor(this.elapsedTime / 3600);
      const minutes = Math.floor((this.elapsedTime % 3600) / 60);
      const seconds = Math.floor(this.elapsedTime % 60);

      // Always use hh:mm:ss format
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    },
    // Format countdown for future start times (always use hh:mm:ss format)
    formattedCountdown() {
      if (this.countdown <= 0) return "00:00:00";

      const hours = Math.floor(this.countdown / 3600);
      const minutes = Math.floor((this.countdown % 3600) / 60);
      const seconds = Math.floor(this.countdown % 60);

      // Always use hh:mm:ss format
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
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

    // Register with shared timer system instead of creating own interval
    const updateFn = () => {
      this.updateTurtlePosition();
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
    this.updateFunction = updateFn;
  },
  beforeUnmount() {
    // Clean up from shared timer registry
    if (this.updateFunction) {
      this.sharedTimerRegistry.intervals.delete(this.updateFunction);
    }

    // Clean up master interval if no more components
    if (this.sharedTimerRegistry.intervals.size === 0 && this.sharedTimerRegistry.masterInterval) {
      clearInterval(this.sharedTimerRegistry.masterInterval);
      this.sharedTimerRegistry.masterInterval = null;
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

      // Only log if position has changed significantly (avoid spam) and debug is enabled
      const roundedPercent = Math.round(progressPercent * 10) / 10; // Round to 1 decimal place
      if (this.debugEnabled && Math.abs(roundedPercent - this.lastLoggedPosition) >= 0.1) {
        console.log(`[Turtle] Position updated: ${this.lastLoggedPosition}% -> ${roundedPercent}%`);
        this.lastLoggedPosition = roundedPercent;
      }

      this.positionPercent = progressPercent;

      // Emit elapsed time updates to parent component
      this.$emit('elapsed-time-update', this.elapsedTime);
    }
  }
};
</script>
