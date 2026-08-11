<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { teamRosters, rosterRoleOrder } from '../data/teamRosters'

const props = defineProps({
  meta: { type: Object, required: true },
  compact: Boolean,
})

const failed = ref(false)
const rosterOpen = ref(false)
const anchor = ref(null)
const placement = ref('below')
const popoverStyle = ref({})
let closeTimer
const roster = computed(() => teamRosters[props.meta.id])
const rosterMembers = computed(() => [...(roster.value?.members || [])].sort((a, b) => (rosterRoleOrder[a.role] ?? 9) - (rosterRoleOrder[b.role] ?? 9)))
watch(() => props.meta.logo, () => { failed.value = false })

function openRoster() {
  clearTimeout(closeTimer)
  rosterOpen.value = true
  nextTick(positionRoster)
  window.addEventListener('resize', positionRoster)
  window.addEventListener('scroll', positionRoster, true)
}

function closeRoster() {
  clearTimeout(closeTimer)
  closeTimer = setTimeout(() => {
    rosterOpen.value = false
    window.removeEventListener('resize', positionRoster)
    window.removeEventListener('scroll', positionRoster, true)
  }, 100)
}

function positionRoster() {
  if (!anchor.value) return
  const rect = anchor.value.getBoundingClientRect()
  const width = Math.min(728, window.innerWidth - 24)
  const center = Math.max(width / 2 + 12, Math.min(rect.left + rect.width / 2, window.innerWidth - width / 2 - 12))
  const panelHeight = 321
  const showAbove = rect.bottom + panelHeight + 12 > window.innerHeight && rect.top > panelHeight + 12
  placement.value = showAbove ? 'above' : 'below'
  popoverStyle.value = {
    left: `${center}px`,
    top: `${showAbove ? rect.top - 10 : rect.bottom + 10}px`,
    width: `${width}px`,
  }
}

function onFocusOut(event) {
  if (!event.currentTarget.contains(event.relatedTarget)) closeRoster()
}

function useUnknownPlayer(event) {
  const fallback = `${window.location.origin}/players/player_unknown.png`
  if (event.currentTarget.src !== fallback) event.currentTarget.src = fallback
}

onBeforeUnmount(() => {
  clearTimeout(closeTimer)
  window.removeEventListener('resize', positionRoster)
  window.removeEventListener('scroll', positionRoster, true)
})
</script>

<template>
  <span
    class="team-roster-trigger"
    :class="{ 'has-roster': roster, 'roster-open': rosterOpen }"
    @mouseenter="openRoster"
    @mouseleave="closeRoster"
    @focusin="openRoster"
    @focusout="onFocusOut"
  >
    <span ref="anchor" class="team-roster-anchor" tabindex="0" :aria-label="`${meta.name} 选手名单`">
      <span :class="compact ? 'mini-logo' : 'team-logo'" :style="{ '--team-color': meta.color }">
        <img v-if="meta.logo && !failed" :src="meta.logo" :alt="`${meta.name} 队标`" loading="lazy" @error="failed = true" />
        <b v-else>{{ meta.short }}</b>
      </span>
    </span>
    <Teleport to="body">
      <span v-if="roster" v-show="rosterOpen" class="team-roster-popover" :class="placement" :style="popoverStyle" role="tooltip" @mouseenter="openRoster" @mouseleave="closeRoster" @click.stop>
        <span class="team-roster-header">
          <span class="team-roster-header-logo"><img :src="meta.logo" :alt="`${meta.name} 队标`" /></span>
          <strong>{{ roster.teamName }}</strong>
        </span>
        <span class="team-roster-members">
          <span v-for="player in rosterMembers" :key="player.accountId" class="team-roster-player">
            <span class="team-roster-role">{{ player.role }}</span>
            <span class="team-roster-portrait"><img :src="player.image" :alt="player.id" loading="lazy" @error="useUnknownPlayer" /></span>
            <span class="team-roster-player-info"><strong><img v-if="player.countryFlag" class="team-roster-country" :src="player.countryFlag" :alt="player.country" :title="player.country" />{{ player.id }}</strong><small>{{ player.realName }}</small></span>
          </span>
        </span>
      </span>
    </Teleport>
  </span>
</template>
