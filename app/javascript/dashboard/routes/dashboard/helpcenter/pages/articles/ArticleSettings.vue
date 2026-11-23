<script>
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import { mapGetters } from 'vuex';
import { debounce } from '@chatwoot/utils';
import { isEmptyObject } from 'dashboard/helper/commons.js';
export default {
  components: {
    MultiselectDropdown,
  },
  props: {
    article: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      metaTitle: '',
      metaDescription: '',
      metaTags: [],
      metaOptions: [],
      tagInputValue: '',
      // Guía de Dali (portal «Guías de Dali»): lo que Dali usa para encontrarla y mostrarla.
      daliAreas: [],
      daliKeywords: [],
      daliPages: [],
      daliReviewed: '',
      keywordInputValue: '',
    };
  },
  computed: {
    ...mapGetters({
      categories: 'categories/allCategories',
      agents: 'agents/getAgents',
    }),
    assignedAuthor() {
      return this.article?.author;
    },
    selectedCategory() {
      return this.article?.category;
    },
    allTags() {
      return this.metaTags.map(item => item.name);
    },
    portal() {
      return (
        this.$store.getters['portals/portalBySlug'](
          this.$route.params.portalSlug
        ) || {}
      );
    },
    daliOptions() {
      return this.portal.dali_guides || null;
    },
    isDaliGuide() {
      return Boolean(
        this.daliOptions && this.article && this.article.dali_guide
      );
    },
    daliKey() {
      return this.isDaliGuide ? this.article.dali_guide.key || '' : '';
    },
    areaOptions() {
      if (!this.daliOptions) return [];
      return this.daliOptions.areas.map(key => ({
        key,
        label: this.$t(`ACCESS_ROLES.AREAS.${key.toUpperCase()}`),
      }));
    },
    pageOptions() {
      return this.daliOptions ? this.daliOptions.pages : [];
    },
    allKeywords() {
      return this.daliKeywords.map(item => item.name);
    },
    hasNoKeywords() {
      return this.isDaliGuide && !this.daliKeywords.length;
    },
  },
  watch: {
    article: {
      handler() {
        if (!isEmptyObject(this.article.meta || {})) {
          const {
            meta: { title = '', description = '', tags = [] },
          } = this.article;
          this.metaTitle = title;
          this.metaDescription = description;
          this.metaTags = this.formattedTags({ tags });
        }
        this.loadDaliGuide();
      },
      deep: true,
      immediate: true,
    },
    isDaliGuide: {
      handler() {
        this.loadDaliGuide();
      },
      immediate: true,
    },
  },
  mounted() {
    this.saveArticle = debounce(
      () => {
        this.$emit('saveArticle', {
          meta: {
            title: this.metaTitle,
            description: this.metaDescription,
            tags: this.allTags,
          },
        });
      },
      1000,
      false
    );
    // Solo manda lo de la guía: el servidor lo combina con el resto del meta.
    this.saveDaliGuide = debounce(
      () => {
        this.$emit('saveArticle', {
          meta: {
            areas: this.daliAreas.map(item => item.key),
            keywords: this.allKeywords,
            pages: this.daliPages.map(item => item.key),
            reviewed: this.daliReviewed || null,
          },
        });
      },
      1000,
      false
    );
  },
  methods: {
    formattedTags({ tags }) {
      return tags.map(tag => ({
        name: tag,
      }));
    },
    addTagValue(tagValue) {
      const tags = tagValue
        .split(',')
        .map(tag => tag.trim())
        .filter(tag => tag && !this.allTags.includes(tag));

      this.metaTags.push(...this.formattedTags({ tags: [...new Set(tags)] }));
      this.saveArticle();
    },
    removeTag() {
      this.saveArticle();
    },
    handleSearchChange(value) {
      this.tagInputValue = value;
    },
    onBlur() {
      if (this.tagInputValue) {
        this.addTagValue(this.tagInputValue);
      }
    },
    onClickSelectCategory({ id }) {
      this.$emit('saveArticle', { category_id: id });
    },
    onClickAssignAuthor({ id }) {
      this.$emit('saveArticle', { author_id: id });
      this.updateMeta();
    },
    onChangeMetaInput() {
      this.saveArticle();
    },
    onClickArchiveArticle() {
      this.$emit('archiveArticle');
      this.updateMeta();
    },
    onClickDeleteArticle() {
      this.$emit('deleteArticle');
      this.updateMeta();
    },
    updateMeta() {
      this.$emit('updateMeta');
    },
    loadDaliGuide() {
      if (!this.isDaliGuide) return;
      const meta = this.article.meta || {};
      const areas = meta.areas || [];
      const pages = meta.pages || [];
      this.daliAreas = this.areaOptions.filter(item =>
        areas.includes(item.key)
      );
      this.daliPages = pages.map(
        key =>
          this.pageOptions.find(item => item.key === key) || {
            key,
            label: key,
          }
      );
      this.daliKeywords = this.formattedTags({ tags: meta.keywords || [] });
      this.daliReviewed = meta.reviewed || '';
    },
    addKeywordValue(value) {
      const keywords = value
        .split(',')
        .map(keyword => keyword.trim())
        .filter(keyword => keyword && !this.allKeywords.includes(keyword));

      this.daliKeywords.push(
        ...this.formattedTags({ tags: [...new Set(keywords)] })
      );
      this.keywordInputValue = '';
      this.saveDaliGuide();
    },
    handleKeywordSearchChange(value) {
      this.keywordInputValue = value;
    },
    onKeywordsBlur() {
      if (this.keywordInputValue) {
        this.addKeywordValue(this.keywordInputValue);
      }
    },
    onChangeDaliGuide() {
      this.saveDaliGuide();
    },
  },
};
</script>

<template>
  <transition name="popover-animation">
    <div
      class="min-w-[15rem] max-w-[22.5rem] p-6 overflow-y-auto border-l rtl:border-r rtl:border-l-0 border-solid border-slate-50 dark:border-slate-700"
    >
      <h3 class="text-base text-slate-800 dark:text-slate-100">
        {{ $t('HELP_CENTER.ARTICLE_SETTINGS.TITLE') }}
      </h3>
      <div class="mt-4 mb-6">
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.CATEGORY.LABEL') }}
          <MultiselectDropdown
            :options="categories"
            :selected-item="selectedCategory"
            :has-thumbnail="false"
            :multiselector-title="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.CATEGORY.TITLE')
            "
            :multiselector-placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.CATEGORY.PLACEHOLDER')
            "
            :no-search-result="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.CATEGORY.NO_RESULT')
            "
            :input-placeholder="
              $t(
                'HELP_CENTER.ARTICLE_SETTINGS.FORM.CATEGORY.SEARCH_PLACEHOLDER'
              )
            "
            @click="onClickSelectCategory"
          />
        </label>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.AUTHOR.LABEL') }}
          <MultiselectDropdown
            :options="agents"
            :selected-item="assignedAuthor"
            :multiselector-title="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.AUTHOR.TITLE')
            "
            :multiselector-placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.AUTHOR.PLACEHOLDER')
            "
            :no-search-result="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.AUTHOR.NO_RESULT')
            "
            :input-placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.AUTHOR.SEARCH_PLACEHOLDER')
            "
            @click="onClickAssignAuthor"
          />
        </label>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.META_TITLE.LABEL') }}
          <textarea
            v-model="metaTitle"
            rows="3"
            type="text"
            :placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.META_TITLE.PLACEHOLDER')
            "
            @input="onChangeMetaInput"
          />
        </label>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.META_DESCRIPTION.LABEL') }}
          <textarea
            v-model="metaDescription"
            class="text-sm"
            rows="3"
            type="text"
            :placeholder="
              $t(
                'HELP_CENTER.ARTICLE_SETTINGS.FORM.META_DESCRIPTION.PLACEHOLDER'
              )
            "
            @input="onChangeMetaInput"
          />
        </label>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.META_TAGS.LABEL') }}
          <multiselect
            v-model="metaTags"
            class="tags-input"
            :placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.META_TAGS.PLACEHOLDER')
            "
            label="name"
            :options="metaOptions"
            track-by="name"
            multiple
            taggable
            :close-on-select="false"
            @search-change="handleSearchChange"
            @close="onBlur"
            @tag="addTagValue"
            @remove="removeTag"
          />
        </label>
      </div>
      <div
        v-if="isDaliGuide"
        class="pt-4 mb-6 border-t border-solid border-slate-50 dark:border-slate-700"
      >
        <h3 class="text-base text-slate-800 dark:text-slate-100">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.TITLE') }}
        </h3>
        <p class="mb-4 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.ABOUT') }}
        </p>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.KEY') }}
          <input :value="daliKey" type="text" readonly />
        </label>
        <p class="-mt-2 mb-4 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.KEY_HELP') }}
        </p>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.AREAS') }}
          <multiselect
            v-model="daliAreas"
            :options="areaOptions"
            track-by="key"
            label="label"
            multiple
            :close-on-select="false"
            :clear-on-select="false"
            :placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.AREAS_PLACEHOLDER')
            "
            selected-label
            :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
            :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
            @input="onChangeDaliGuide"
          />
        </label>
        <p class="mt-1 mb-4 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.AREAS_HELP') }}
        </p>
        <label>
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.KEYWORDS') }}
          <multiselect
            v-model="daliKeywords"
            class="tags-input"
            :placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.KEYWORDS_PLACEHOLDER')
            "
            label="name"
            :options="[]"
            track-by="name"
            multiple
            taggable
            :close-on-select="false"
            @search-change="handleKeywordSearchChange"
            @close="onKeywordsBlur"
            @tag="addKeywordValue"
            @remove="onChangeDaliGuide"
          />
        </label>
        <p v-if="hasNoKeywords" class="mt-1 mb-4 text-xs text-red-600">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.KEYWORDS_EMPTY') }}
        </p>
        <label class="mt-4">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.PAGES') }}
          <multiselect
            v-model="daliPages"
            :options="pageOptions"
            track-by="key"
            label="label"
            multiple
            :close-on-select="false"
            :clear-on-select="false"
            :placeholder="
              $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.PAGES_PLACEHOLDER')
            "
            selected-label
            :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
            :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
            @input="onChangeDaliGuide"
          />
        </label>
        <label class="mt-4">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.REVIEWED') }}
          <input
            v-model="daliReviewed"
            type="date"
            @change="onChangeDaliGuide"
          />
        </label>
        <p class="-mt-2 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.FORM.DALI.REVIEWED_HELP') }}
        </p>
      </div>
      <div class="flex flex-col">
        <woot-button
          icon="archive"
          size="small"
          variant="clear"
          color-scheme="secondary"
          @click="onClickArchiveArticle"
        >
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.BUTTONS.ARCHIVE') }}
        </woot-button>
        <woot-button
          icon="delete"
          size="small"
          variant="clear"
          color-scheme="alert"
          @click="onClickDeleteArticle"
        >
          {{ $t('HELP_CENTER.ARTICLE_SETTINGS.BUTTONS.DELETE') }}
        </woot-button>
      </div>
    </div>
  </transition>
</template>

<style lang="scss" scoped>
::v-deep {
  .multiselect {
    @apply mb-0;
  }

  // Etiquetas y palabras clave se escriben libres: sin lista desplegable.
  .tags-input .multiselect__content-wrapper,
  .tags-input .multiselect__select {
    @apply hidden;
  }

  .multiselect--active .multiselect__tags {
    padding-right: var(--space-small) !important;
    @apply rounded-md;
  }

  .multiselect__placeholder {
    @apply text-slate-300 dark:text-slate-200 pt-2 mb-0;
  }
}
</style>
