<template>
    <!-- Configuration Dialog -->
    <div v-if="show" class="config-dialog" :class="{ 'dark-mode': isDarkMode }" @click.stop>
        <div class="dialog-content">
            <h3>Presentation Timer Settings</h3>

            <!-- Presentation Start Time Section -->
            <div class="time-inputs">
                <label>
                    <span>Presentation Start Time:</span>
                </label>
                <div class="start-time-section">
                    <button @click="setStartTimeNow" class="small-button">Start Now</button>
                    <span style="margin: 0 8px;">or</span>
                    <input type="datetime-local" v-model="presentationStartInput" />
                    <button @click="clearStartTime" class="small-button">Clear</button>
                </div>
                <p class="help-text">Set when the presentation should begin. Slide timers will be paused until this
                    time.</p>
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

            <!-- Slide Time Management -->
            <div class="time-inputs">
                <h4>Slide Time Management</h4>
                <div class="slide-time-management">
                    <button @click="clearSlideTimes" class="danger-button">Clear All Slide Times</button>
                    <button @click="exportSlideTimes" class="export-button">Export Slide Times</button>
                </div>
                <p class="help-text">Clear all stored slide timing data or export it for analysis.</p>
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
const TARGET_COMPLETION_KEY = `${STORAGE_KEY_PREFIX}target-completion`;
const PRESENTATION_START_KEY = `${STORAGE_KEY_PREFIX}presentation-start-time`;
const SLIDE_TIMES_KEY = 'slidev-turtle-slide-times';

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
        const storedTargetCompletion = localStorage.getItem(TARGET_COMPLETION_KEY);
        const storedPresentationStart = localStorage.getItem(PRESENTATION_START_KEY);

        return {
            useTargetCompletion: !!storedTargetCompletion,
            targetCompletionInput: '',
            // Format date in local timezone
            presentationStartInput: storedPresentationStart ?
                this.formatDateForLocalInput(new Date(parseInt(storedPresentationStart))) : ''
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
            // Save target completion settings
            if (this.useTargetCompletion) {
                const targetCompletion = new Date(this.targetCompletionInput).getTime();
                localStorage.setItem(TARGET_COMPLETION_KEY, targetCompletion.toString());
            } else {
                // Remove target completion settings
                localStorage.removeItem(TARGET_COMPLETION_KEY);
            }

            // Save presentation start time
            if (this.presentationStartInput) {
                const presentationStart = new Date(this.presentationStartInput).getTime();
                localStorage.setItem(PRESENTATION_START_KEY, presentationStart.toString());
            }

            // Signal to parent that settings have changed
            this.$emit('settings-updated');
            this.closeDialog();

            // Force page reload to ensure all components pick up the new settings
            window.location.reload();
        },

        resetSettings() {
            // Reset everything to defaults
            localStorage.removeItem(TARGET_COMPLETION_KEY);
            localStorage.removeItem(PRESENTATION_START_KEY);

            this.useTargetCompletion = false;
            this.presentationStartInput = '';
            this.closeDialog();

            // Force page reload
            window.location.reload();
        },

        setStartTimeNow() {
            const now = Date.now();
            localStorage.setItem(PRESENTATION_START_KEY, now.toString());
            this.presentationStartInput = this.formatDateForLocalInput(new Date(now));

            // Notify other components
            window.dispatchEvent(new StorageEvent('storage', {
                key: PRESENTATION_START_KEY,
                newValue: now.toString()
            }));
        },

        clearStartTime() {
            localStorage.removeItem(PRESENTATION_START_KEY);
            this.presentationStartInput = '';

            // Notify other components
            window.dispatchEvent(new StorageEvent('storage', {
                key: PRESENTATION_START_KEY,
                newValue: null
            }));
        },

        clearSlideTimes() {
            if (confirm('Are you sure you want to clear all slide timing data? This cannot be undone.')) {
                localStorage.removeItem(SLIDE_TIMES_KEY);

                // Notify other components
                window.dispatchEvent(new StorageEvent('storage', {
                    key: SLIDE_TIMES_KEY,
                    newValue: null
                }));

                alert('All slide timing data has been cleared.');
            }
        },

        exportSlideTimes() {
            const savedTimes = localStorage.getItem(SLIDE_TIMES_KEY);
            if (!savedTimes) {
                alert('No slide timing data available to export.');
                return;
            }

            try {
                const slideTimes = JSON.parse(savedTimes);
                const slides = $slidev.nav.slides;
                const defaultSlideTime = $slidev.configs?.rabbit?.defaultSlideTime || 2;

                // Format current date and time for filename
                const now = new Date();
                const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
                const timeStr = `${String(now.getHours()).padStart(2, '0')}-${String(now.getMinutes()).padStart(2, '0')}`;

                // Build comprehensive export data
                const exportData = {
                    metadata: {
                        exportDate: now.toISOString(),
                        totalSlides: slides.length,
                        slidesWithRecordedTimes: Object.keys(slideTimes).length
                    },
                    slideData: [],
                    summary: {
                        totalPlannedTime: 0,
                        totalActualTime: 0,
                        totalVariance: 0,
                        slidesAhead: 0,
                        slidesBehind: 0,
                        slidesOnTime: 0
                    }
                };

                // Process each slide
                slides.forEach((slide, index) => {
                    const slideNum = index + 1;
                    const slideTitle = slide.meta?.slide?.frontmatter?.title || `Slide ${slideNum}`;
                    const plannedTimeMin = slide.meta?.slide?.frontmatter?.slideTime || defaultSlideTime;
                    const actualTimeSec = slideTimes[slideNum] || 0;
                    const actualTimeMin = actualTimeSec / 60;
                    const variance = plannedTimeMin - actualTimeMin;

                    // Add to summary
                    exportData.summary.totalPlannedTime += plannedTimeMin;
                    exportData.summary.totalActualTime += actualTimeMin;
                    exportData.summary.totalVariance += variance;

                    if (variance > 0.25) exportData.summary.slidesAhead++;
                    else if (variance < -0.25) exportData.summary.slidesBehind++;
                    else exportData.summary.slidesOnTime++;

                    // Add slide data
                    exportData.slideData.push({
                        slideNumber: slideNum,
                        title: slideTitle,
                        plannedTimeMinutes: plannedTimeMin,
                        actualTimeSeconds: actualTimeSec,
                        actualTimeMinutes: actualTimeMin,
                        variance: variance,
                        status: variance > 0.25 ? 'ahead' : (variance < -0.25 ? 'behind' : 'on-time')
                    });
                });

                // Calculate averages
                if (exportData.slideData.length > 0) {
                    exportData.summary.averagePlannedTime = exportData.summary.totalPlannedTime / exportData.slideData.length;
                    exportData.summary.averageActualTime = exportData.summary.totalActualTime / exportData.slideData.length;
                    exportData.summary.averageVariance = exportData.summary.totalVariance / exportData.slideData.length;
                }

                // Convert to JSON and create download
                const jsonStr = JSON.stringify(exportData, null, 2);
                const blob = new Blob([jsonStr], { type: 'application/json' });
                const url = URL.createObjectURL(blob);

                const a = document.createElement('a');
                a.href = url;
                a.download = `slide-times-${dateStr}-${timeStr}.json`;
                document.body.appendChild(a);
                a.click();

                // Clean up
                setTimeout(() => {
                    document.body.removeChild(a);
                    window.URL.revokeObjectURL(url);
                }, 0);
            } catch (e) {
                console.error('Error exporting slide times:', e);
                alert('Error exporting slide times. Check console for details.');
            }
        },

        formatDateForLocalInput(date) {
            // Format date for datetime-local input in local timezone
            const year = date.getFullYear();
            const month = (date.getMonth() + 1).toString().padStart(2, '0');
            const day = date.getDate().toString().padStart(2, '0');
            const hours = date.getHours().toString().padStart(2, '0');
            const minutes = date.getMinutes().toString().padStart(2, '0');

            return `${year}-${month}-${day}T${hours}:${minutes}`;
        },

        initializeTargetCompletionInput() {
            const storedTargetCompletion = localStorage.getItem(TARGET_COMPLETION_KEY);
            let targetDate = new Date();

            if (storedTargetCompletion) {
                targetDate.setTime(parseInt(storedTargetCompletion));
            } else {
                // Default to 1 hour from now
                targetDate.setTime(Date.now() + (60 * 60 * 1000)); // +1 hour
            }

            this.targetCompletionInput = this.formatDateForLocalInput(targetDate);
        }
    },
    watch: {
        // Initialize inputs when dialog becomes visible
        show: {
            handler(newShow) {
                if (newShow) {
                    this.initializeTargetCompletionInput();
                }
            },
            immediate: true
        }
    }
}
</script>

<style scoped>
.start-time-section {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 8px;
}

.small-button {
    padding: 4px 8px;
    font-size: 0.8rem;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #f8f9fa;
    cursor: pointer;
    transition: background-color 0.2s;
}

.small-button:hover {
    background: #e9ecef;
}

.dark-mode .small-button {
    background: #374151;
    border-color: #4b5563;
    color: #f9fafb;
}

.dark-mode .small-button:hover {
    background: #4b5563;
}

.help-text {
    font-size: 0.8rem;
    color: #6b7280;
    margin-top: 4px;
    margin-bottom: 0;
}

.dark-mode .help-text {
    color: #9ca3af;
}

.slide-time-management {
    display: flex;
    gap: 8px;
    margin-top: 8px;
}

.danger-button {
    background: #ef4444;
    color: white;
    border: 1px solid #dc2626;
    padding: 4px 8px;
    font-size: 0.8rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.2s;
}

.danger-button:hover {
    background: #dc2626;
}

.export-button {
    background: #3b82f6;
    color: white;
    border: 1px solid #2563eb;
    padding: 4px 8px;
    font-size: 0.8rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.2s;
}

.export-button:hover {
    background: #2563eb;
}

.dark-mode .danger-button {
    background: #b91c1c;
    border-color: #991b1b;
}

.dark-mode .danger-button:hover {
    background: #991b1b;
}

.dark-mode .export-button {
    background: #3b82f6;
    border-color: #2563eb;
}

.dark-mode .export-button:hover {
    background: #2563eb;
}
</style>