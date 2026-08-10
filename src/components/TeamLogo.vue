<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  meta: { type: Object, required: true },
  compact: Boolean,
})

const failed = ref(false)
watch(() => props.meta.logo, () => { failed.value = false })
</script>

<template>
  <span :class="compact ? 'mini-logo' : 'team-logo'" :style="{ '--team-color': meta.color }">
    <img v-if="meta.logo && !failed" :src="meta.logo" :alt="`${meta.name} 队标`" loading="lazy" @error="failed = true" />
    <b v-else>{{ meta.short }}</b>
  </span>
</template>
