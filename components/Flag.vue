<template>
  <div>
    <div class="flag-container" @click="openConfigDialog">
      <emojione-monotone-flag-for-chequered-flag class="icon config-icon" />
    </div>

    <!-- Configuration Dialog -->
    <div v-if="showDialog" class="config-dialog" @click.stop>
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

.time-inputs input {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.dialog-buttons {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}

.dialog-buttons button {
  padding: 6px 12px;
  border-radius: 4px;
  border: none;
  background: #f1f1f1;
  cursor: pointer;
}

.dialog-buttons button:first-child {
  background: #4a8fe7;
  color: white;
}
</style>
