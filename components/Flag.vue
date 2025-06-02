<template>
  <div>

    <!-- Countdown display -->
    <div class="counter-display countdown-display" :class="countdownClass">
      {{ formattedCountdown }}
    </div>

    <!-- Flag / Configuration Icon -->
    <div class="flag-container" @click="openConfigDialog">
      <emojione-monotone-flag-for-chequered-flag class="icon config-icon flag-icon" />
      <emojione-monotone-gear class="icon config-icon gear-icon" />
    </div>


    <!-- Total slide time display -->
    <div class="counter-display total-time-display">
      {{ formattedTotalTime }}
    </div>

    <!-- Configuration Dialog -->
    <div v-if="showDialog" class="config-dialog" :class="{ 'dark-mode': isDarkMode }" @click.stop>
      <div class="dialog-content">
        <h3>Presentation Timer Settings</h3>

        <div class="mode-selector">
          <label>
            <input type="radio" v-model="timerMode" value="incremental" />
            <span>Incremental Mode (starts from 0)</span>
          </label>
          <label>
            <input type="radio" v-model="timerMode" value="wallclock" />
            <span>Wall Clock Mode (based on real time)</span>
          </label>
        </div>

        <div v-if="timerMode === 'wallclock'" class="time-inputs">
          <p>Set presentation start time:</p>
          <input type="datetime-local" v-model="startTimeInput" />
        </div>

        <div class="dialog-buttons">
          <button @click="saveSettings">Save</button>
          <button @click="resetSettings">Reset</button>
          <button @click="closeDialog">Cancel</button>
        </div>
      </div>
    </div>
    <div v-if="showDialog" class="dialog-overlay" @click="closeDialog"></div>
  </div>
</template>

<script>
const STORAGE_KEY_PREFIX = 'slidev-turtle-';
const MODE_KEY = `${STORAGE_KEY_PREFIX}mode`;
const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`;

export default {
  props: {
    left: Number,
    slideTimes: {
      type: Array,
      default: () => []
    },
    totalTimeMinutes: {
      type: Number,
      default: 10
    },
    turtleElapsedTime: {
      type: Number,
      default: 0
    }
  },
  data() {
    const storedMode = localStorage.getItem(MODE_KEY) || 'incremental';
    const storedStartTime = localStorage.getItem(START_TIME_KEY);

    return {
      showDialog: false,
      timerMode: storedMode,
      startTimeInput: '',
    }
  },
  computed: {
    formattedTotalTime() {
      const totalMinutes = this.totalTimeMinutes;
      const hours = Math.floor(totalMinutes / 60);
      const minutes = Math.floor(totalMinutes % 60);
      const seconds = Math.floor((totalMinutes % 1) * 60);

      return `TT ${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    },

    // Calculate remaining time (total time - turtle elapsed time)
    remainingTimeSeconds() {
      const totalTimeSeconds = this.totalTimeMinutes * 60;
      const turtleElapsedSeconds = this.turtleElapsedTime;
      return totalTimeSeconds - turtleElapsedSeconds;
    },

    // Format countdown display
    formattedCountdown() {
      const remainingSeconds = Math.abs(this.remainingTimeSeconds);
      const hours = Math.floor(remainingSeconds / 3600);
      const minutes = Math.floor((remainingSeconds % 3600) / 60);
      const seconds = Math.floor(remainingSeconds % 60);

      const sign = this.remainingTimeSeconds < 0 ? '-' : '';

      return `TR ${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    },

    // CSS class for countdown styling
    countdownClass() {
      if (this.remainingTimeSeconds < 0) {
        return 'time-behind'; // Red when over time
      } else if (this.remainingTimeSeconds < 60) {
        return 'time-warning'; // Yellow when less than 1 minute left
      } else {
        return 'time-ahead'; // Green when plenty of time left
      }
    },

    // Detect dark mode from various sources
    isDarkMode() {
      // Check multiple ways Slidev might indicate dark mode
      const body = document.body;
      const html = document.documentElement;

      // Check for common dark mode classes
      if (body.classList.contains('dark') ||
        html.classList.contains('dark') ||
        body.classList.contains('dark-mode') ||
        html.classList.contains('dark-mode')) {
        return true;
      }

      // Check for data attributes
      if (html.getAttribute('data-theme') === 'dark' ||
        body.getAttribute('data-theme') === 'dark') {
        return true;
      }

      // Check CSS custom properties for dark themes
      const computedStyle = getComputedStyle(html);
      const bgColor = computedStyle.getPropertyValue('--slidev-theme-background') ||
        computedStyle.getPropertyValue('--background') ||
        computedStyle.backgroundColor;

      // If background is dark (heuristic check)
      if (bgColor && bgColor !== 'transparent') {
        // Convert to RGB values and check if it's closer to black than white
        const rgb = this.parseColor(bgColor);
        if (rgb) {
          const brightness = (rgb.r * 299 + rgb.g * 587 + rgb.b * 114) / 1000;
          return brightness < 128; // Dark if brightness is less than 50%
        }
      }

      // Check for prefers-color-scheme
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        // Only use system preference as fallback if no explicit theme is set
        const hasExplicitTheme = body.className.includes('theme-') ||
          html.className.includes('theme-');
        if (!hasExplicitTheme) {
          return true;
        }
      }

      return false;
    }
  },
  methods: {
    openConfigDialog() {
      // Set default datetime to current LOCAL time (not UTC)
      const defaultDate = new Date();
      // If we have a stored start time and using wall clock mode, use that instead
      const storedStartTime = localStorage.getItem(START_TIME_KEY);
      if (storedStartTime && this.timerMode === 'wallclock') {
        defaultDate.setTime(parseInt(storedStartTime));
      }

      // Format date for input: YYYY-MM-DDThh:mm using LOCAL time
      const year = defaultDate.getFullYear();
      const month = (defaultDate.getMonth() + 1).toString().padStart(2, '0');
      const day = defaultDate.getDate().toString().padStart(2, '0');
      const hours = defaultDate.getHours().toString().padStart(2, '0');
      const minutes = defaultDate.getMinutes().toString().padStart(2, '0');

      this.startTimeInput = `${year}-${month}-${day}T${hours}:${minutes}`;
      this.showDialog = true;
    },
    closeDialog() {
      this.showDialog = false;
    },
    saveSettings() {
      // Save the timer mode
      localStorage.setItem(MODE_KEY, this.timerMode);

      if (this.timerMode === 'incremental') {
        // For incremental, we use the current time as the start
        localStorage.setItem(START_TIME_KEY, Date.now().toString());
      } else if (this.timerMode === 'wallclock') {
        // For wall clock, save the selected start time
        const newStartTime = new Date(this.startTimeInput).getTime();
        localStorage.setItem(START_TIME_KEY, newStartTime.toString());
      }

      // Signal to parent that settings have changed (useful for reactivity)
      this.$emit('settings-updated');

      this.closeDialog();

      // Force page reload to ensure all components pick up the new settings
      window.location.reload();
    },
    resetSettings() {
      // Reset everything to defaults
      localStorage.removeItem(MODE_KEY);
      localStorage.removeItem(START_TIME_KEY);

      this.timerMode = 'incremental';
      this.closeDialog();

      // Force page reload
      window.location.reload();
    },

    // Helper method to parse color strings to RGB
    parseColor(color) {
      if (!color) return null;

      // Handle rgb() format
      const rgbMatch = color.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
      if (rgbMatch) {
        return {
          r: parseInt(rgbMatch[1]),
          g: parseInt(rgbMatch[2]),
          b: parseInt(rgbMatch[3])
        };
      }

      // Handle rgba() format
      const rgbaMatch = color.match(/rgba\((\d+),\s*(\d+),\s*(\d+),\s*[\d.]+\)/);
      if (rgbaMatch) {
        return {
          r: parseInt(rgbaMatch[1]),
          g: parseInt(rgbaMatch[2]),
          b: parseInt(rgbaMatch[3])
        };
      }

      // Handle hex format
      const hexMatch = color.match(/^#([a-f\d]{6})$/i);
      if (hexMatch) {
        const hex = hexMatch[1];
        return {
          r: parseInt(hex.substr(0, 2), 16),
          g: parseInt(hex.substr(2, 2), 16),
          b: parseInt(hex.substr(4, 2), 16)
        };
      }

      return null;
    }
  }
}
</script>

<style>
.config-icon {
  cursor: pointer;
}

.config-icon:hover {
  opacity: 0.8;
}

.total-time-display {
  z-index: 101;
  min-width: 3.5rem;
  height: auto;
  /* Use minimal height instead of default 70% */
  padding: 0.1rem 0.15rem;
  /* Reduce vertical padding */
  font-size: 0.6rem;
  /* Slightly smaller font for compact display */
}

.countdown-display {
  z-index: 101;
  min-width: 3.5rem;
  height: auto;
  /* Use minimal height instead of default 70% */
  padding: 0.1rem 0.15rem;
  /* Reduce vertical padding */
  font-size: 0.6rem;
  /* Slightly smaller font for compact display */
}

/* Configuration Dialog - Light Mode (Default) */
.config-dialog {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background: white;
  border-radius: 8px;
  padding: 20px;
  z-index: 1000;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
  color: #333;
  min-width: 300px;
  transition: background-color 0.2s ease, color 0.2s ease;
}

/* Configuration Dialog - Dark Mode */
.config-dialog.dark-mode {
  background: #2d3748;
  color: #f7fafc;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.6);
}

.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 999;
}

.dialog-content h3 {
  margin-top: 0;
  margin-bottom: 16px;
  font-size: 18px;
}

.mode-selector {
  margin-bottom: 16px;
}

.mode-selector label {
  display: block;
  margin-bottom: 8px;
  cursor: pointer;
  transition: color 0.2s ease;
}

.mode-selector input {
  margin-right: 8px;
}

.time-inputs {
  margin-bottom: 16px;
}

.time-inputs p {
  margin-bottom: 8px;
  font-size: 14px;
}

/* Input styling for both light and dark modes */
.time-inputs input {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  color: #333;
  transition: border-color 0.2s ease, background-color 0.2s ease, color 0.2s ease;
}

.dark-mode .time-inputs input {
  background: #4a5568;
  border-color: #718096;
  color: #f7fafc;
}

.dark-mode .time-inputs input:focus {
  border-color: #63b3ed;
  outline: none;
  box-shadow: 0 0 0 2px rgba(99, 179, 237, 0.2);
}

.time-inputs input:focus {
  border-color: #4a8fe7;
  outline: none;
  box-shadow: 0 0 0 2px rgba(74, 143, 231, 0.2);
}

.dialog-buttons {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}

/* Button styling for both light and dark modes */
.dialog-buttons button {
  padding: 6px 12px;
  border-radius: 4px;
  border: none;
  background: #f1f1f1;
  color: #333;
  cursor: pointer;
  transition: background-color 0.2s ease, color 0.2s ease;
}

.dialog-buttons button:hover {
  background: #e2e8f0;
}

.dialog-buttons button:first-child {
  background: #4a8fe7;
  color: white;
}

.dialog-buttons button:first-child:hover {
  background: #3182ce;
}

/* Dark mode button styles */
.dark-mode .dialog-buttons button {
  background: #4a5568;
  color: #f7fafc;
}

.dark-mode .dialog-buttons button:hover {
  background: #718096;
}

.dark-mode .dialog-buttons button:first-child {
  background: #4a8fe7;
  color: white;
}

.dark-mode .dialog-buttons button:first-child:hover {
  background: #3182ce;
}

/* Flag container hover effects */
.flag-container {
  position: relative;
}

.flag-container .gear-icon {
  display: none;
  /* Hide gear by default */
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%) scale(1, 1);
  /* Center and override the scale flip */
}

.flag-container:hover .flag-icon {
  display: none;
  /* Hide flag on hover */
}

.flag-container:hover .gear-icon {
  display: block;
  /* Show gear on hover */
}
</style>
