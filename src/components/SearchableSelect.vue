<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { Check, ChevronDown, X } from 'lucide-vue-next'

const props = defineProps({
  modelValue: { type: String, default: '' },
  options: { type: Array, default: () => [] },
  placeholder: { type: String, default: '全部' },
})
const emit = defineEmits(['update:modelValue'])

const open = ref(false)
const query = ref('')
const input = ref(null)

const selectedOption = computed(() => props.options.find(option => option.value === props.modelValue) || null)
const filteredOptions = computed(() => {
  const keyword = query.value.trim().toLocaleLowerCase()
  if (!keyword) return props.options
  return props.options.filter(option => option.label.toLocaleLowerCase().includes(keyword))
})

watch(() => props.modelValue, () => {
  if (!open.value) query.value = selectedOption.value?.label || ''
}, { immediate: true })

function openList() {
  open.value = true
  query.value = ''
  nextTick(() => input.value?.focus())
}

function choose(option) {
  emit('update:modelValue', option.value)
  query.value = option.label
  open.value = false
}

function clear() {
  emit('update:modelValue', '')
  query.value = ''
  open.value = true
  nextTick(() => input.value?.focus())
}

function handleInput(event) {
  query.value = event.target.value
  if (props.modelValue) emit('update:modelValue', '')
  open.value = true
}

function chooseFirst() {
  if (open.value && filteredOptions.value.length) choose(filteredOptions.value[0])
}

function closeList() {
  window.setTimeout(() => {
    open.value = false
    query.value = selectedOption.value?.label || ''
  }, 120)
}
</script>

<template>
  <div class="searchable-select" :class="{ open }">
    <input
      ref="input"
      :value="open ? query : (selectedOption?.label || '')"
      :placeholder="placeholder"
      autocomplete="off"
      role="combobox"
      :aria-expanded="open"
      aria-autocomplete="list"
      @focus="openList"
      @input="handleInput"
      @keydown.enter.prevent="chooseFirst"
      @keydown.escape="closeList"
      @blur="closeList"
    />
    <button v-if="modelValue" type="button" class="searchable-select-clear" aria-label="清除选择" @mousedown.prevent @click="clear"><X :size="14" /></button>
    <ChevronDown v-else class="searchable-select-arrow" :size="16" />
    <div v-if="open" class="searchable-select-menu" role="listbox">
      <button type="button" :class="{ selected: modelValue === '' }" role="option" @mousedown.prevent @click="choose({ value: '', label: placeholder })"><span>{{ placeholder }}</span><Check v-if="modelValue === ''" :size="14" /></button>
      <button v-for="option in filteredOptions" :key="option.value" type="button" :class="{ selected: modelValue === option.value }" role="option" @mousedown.prevent @click="choose(option)"><span>{{ option.label }}</span><Check v-if="modelValue === option.value" :size="14" /></button>
      <p v-if="!filteredOptions.length">没有匹配项</p>
    </div>
  </div>
</template>
