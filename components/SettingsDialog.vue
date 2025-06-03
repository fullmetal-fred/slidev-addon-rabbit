<template>
    <!-- Configuration Dialog -->
    <div v-if="show" class="config-dialog" :class="{ 'dark-mode': isDarkMode }" @click.stop>
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

            <!-- Target Completion Time Section -->
            <div class="time-inputs">
                <label>
                    <input type="checkbox" v-model="useTargetCompletion" />
                    <span>Set target completion time (for time banking)</span>
                </label>
                <div v-if="useTargetCompletion" class="target-completion-section">
                    <p>Target completion time:</p>
                    <input type="datetime-local" v-model="targetCompletionInput" />
                </div>
            </div>

            <div class="dialog-buttons">
                <button @click="saveSettings">Save</button>
                <button @click="resetSettings">Reset</button>
                <button @click="closeDialog">Cancel</button>
            </div>
        </div>
    </div>
    <div v-if="show" class="dialog-overlay" @click="closeDialog"></div>
</template>

<script>
const STORAGE_KEY_PREFIX = 'slidev-turtle-';
const MODE_KEY = `${STORAGE_KEY_PREFIX}mode`;
const START_TIME_KEY = `${STORAGE_KEY_PREFIX}start-time`;
const TARGET_COMPLETION_KEY = `${STORAGE_KEY_PREFIX}target-completion`;

export default {
    name: 'SettingsDialog',
    props: {
        show: {
            type: Boolean,
            default: false
        }
    },
    emits: ['close', 'settings-updated'],
    data() {
        const storedMode = localStorage.getItem(MODE_KEY) || 'incremental';
        const storedTargetCompletion = localStorage.getItem(TARGET_COMPLETION_KEY);

        return {
            timerMode: storedMode,
            startTimeInput: '',
            useTargetCompletion: !!storedTargetCompletion,
            targetCompletionInput: ''
        }
    },
    computed: {
        // Detect dark mode for dialog styling
        isDarkMode() {
            const body = document.body;
            const html = document.documentElement;

            return body.classList.contains('dark') ||
                html.classList.contains('dark') ||
                body.classList.contains('dark-mode') ||
                html.classList.contains('dark-mode') ||
                html.getAttribute('data-theme') === 'dark' ||
                body.getAttribute('data-theme') === 'dark';
        }
    },
    methods: {
        closeDialog() {
            this.$emit('close');
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

            // Save target completion settings
            if (this.useTargetCompletion) {
                const targetCompletion = new Date(this.targetCompletionInput).getTime();
                localStorage.setItem(TARGET_COMPLETION_KEY, targetCompletion.toString());
            } else {
                // Remove target completion settings
                localStorage.removeItem(TARGET_COMPLETION_KEY);
            }

            // Signal to parent that settings have changed
            this.$emit('settings-updated');
            this.closeDialog();

            // Force page reload to ensure all components pick up the new settings
            window.location.reload();
        },

        resetSettings() {
            // Reset everything to defaults
            localStorage.removeItem(MODE_KEY);
            localStorage.removeItem(START_TIME_KEY);
            localStorage.removeItem(TARGET_COMPLETION_KEY);

            this.timerMode = 'incremental';
            this.useTargetCompletion = false;
            this.closeDialog();

            // Force page reload
            window.location.reload();
        },

        initializeStartTimeInput() {
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
        },

        initializeTargetCompletionInput() {
            const storedTargetCompletion = localStorage.getItem(TARGET_COMPLETION_KEY);
            let targetDate = new Date();

            if (storedTargetCompletion) {
                targetDate.setTime(parseInt(storedTargetCompletion));
            } else {
                // Default to 1 hour from start time
                const startTime = this.timerMode === 'wallclock' && localStorage.getItem(START_TIME_KEY)
                    ? parseInt(localStorage.getItem(START_TIME_KEY))
                    : Date.now();
                targetDate.setTime(startTime + (60 * 60 * 1000)); // +1 hour
            }

            // Format for datetime-local input
            const year = targetDate.getFullYear();
            const month = (targetDate.getMonth() + 1).toString().padStart(2, '0');
            const day = targetDate.getDate().toString().padStart(2, '0');
            const hours = targetDate.getHours().toString().padStart(2, '0');
            const minutes = targetDate.getMinutes().toString().padStart(2, '0');

            this.targetCompletionInput = `${year}-${month}-${day}T${hours}:${minutes}`;
        }
    },
    watch: {
        // Initialize inputs when dialog becomes visible
        show: {
            handler(newShow) {
                if (newShow) {
                    this.initializeStartTimeInput();
                    this.initializeTargetCompletionInput();
                }
            },
            immediate: true
        }
    }
}
</script>