<template>
  <div class="mt-6 flex-1">
    <div class="mx-0 flex flex-wrap">
      <div class="flex-shrink-0 flex-grow-0 w-full md:w-[65%]">
        <form class="mx-0 flex flex-wrap">

          <div class="w-full flex items-center gap-2">
            <input type="checkbox" :value="true" />
            <label for="conversation_creation">
              {{ 'Activar menú del sistema' }}
            </label>
          </div>

          <div class="w-full flex items-center gap-2">
            <input type="checkbox" :value="true" />
            <label for="conversation_creation">
              {{ 'No mostrar resultado de palabras clave' }}
            </label>
          </div>
          
        </form>
      </div>
    </div>
  </div>
</template>
