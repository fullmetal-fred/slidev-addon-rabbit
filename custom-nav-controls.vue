<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import TimerBar from './components/TimerBar.vue'
import SettingsDialog from './components/SettingsDialog.vue'

// Reactive state for dialog visibility
const showSettingsDialog = ref(false)

// Handle settings dialog open event
const handleOpenSettings = () => {
    showSettingsDialog.value = true
}

// Handle settings updated
const onSettingsUpdated = () => {
    showSettingsDialog.value = false
    // Trigger a storage event to notify other components
    window.dispatchEvent(new StorageEvent('storage', {
        key: 'slidev-turtle-settings-updated',
        newValue: Date.now().toString()
    }))
}

// Set up event listeners
onMounted(() => {
    window.addEventListener('rabbit-open-settings', handleOpenSettings)
})

onUnmounted(() => {
    window.removeEventListener('rabbit-open-settings', handleOpenSettings)
})
</script>

<template>
    <TimerBar />

    <SettingsDialog :show="showSettingsDialog" @close="showSettingsDialog = false"
        @settings-updated="onSettingsUpdated" />
</template>
