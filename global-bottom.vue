<template>
  <!-- when exporting, this footer isn't exported -->
  <footer v-if="$route.query.print !== null" class="rablte-container">
    <!-- Race track container with clear separation of lanes and finish area -->
    <div class="race-track">
      <!-- Lanes container (all but finish-line area) -->
      <div class="lanes">
        <!-- Rabbit lane -->
        <div class="rabbit-lane">
          <Rabbit :current="$slidev.nav.currentPage" :slide-times="slideTimes"
            :use-slide-times-enabled="useSlideTimesEnabled" />
        </div>

        <!-- Divider line -->
        <div class="lane-divider"></div>

        <!-- Turtle lane -->
        <div class="turtle-lane">
          <Turtle :current="$slidev.nav.currentPage" :total-time="totalTimeMinutes" />
        </div>
      </div>

      <!-- Finish line area -->
      <div class="finish-area">
        <Flag />
      </div>
    </div>
  </footer>
</template>

<script>
export default {
  data() {
    const useSlideTimesEnabled = this.$slidev.configs?.rabbit?.useSlideTimes ?? false;
    const slideTimes = this.getSlideTimes();
    // Convert query time parameter to number
    const queryTimeParam = this.$route.query.time ? parseFloat(this.$route.query.time) : 10;
    const totalTimeMinutes = useSlideTimesEnabled ? this.calculateTotalTime(slideTimes, queryTimeParam) : queryTimeParam;

    console.log('[RabbitDebug] Configuration:', {
      useSlideTimesEnabled,
      totalTimeMinutes,
      hasSlideTimes: slideTimes.length > 0 && slideTimes.some(time => time > 0),
      slideTimes,
      rabbitConfig: this.$slidev.configs.rabbit
    });

    return {
      slideTimes,
      totalTimeMinutes,
      useSlideTimesEnabled,
      hasSlideTimes: slideTimes.length > 0 && slideTimes.some(time => time > 0)
    }
  },
  methods: {
    getSlideTimes() {
      // Get all slides and extract time from frontmatter
      const slides = this.$slidev.nav.slides;
      const defaultSlideTime = this.$slidev.configs?.rabbit?.defaultSlideTime || 2; // Default to 2 minutes if not configured

      console.log('[RabbitDebug] Get slides object:', slides);
      console.log('[RabbitDebug] Default slide time configuration:', {
        configuredValue: this.$slidev.configs?.rabbit?.defaultSlideTime,
        effectiveDefault: defaultSlideTime,
        rabbitConfig: this.$slidev.configs?.rabbit
      });

      const times = slides.map((slide, index) => {
        // Priority: 1. slideTime frontmatter, 2. defaultSlideTime config, 3. hardcoded 2 minutes
        const slideTime = slide.meta.slide.frontmatter?.slideTime;
        const time = slideTime !== undefined ? parseFloat(slideTime) : defaultSlideTime;
        const finalTime = !isNaN(time) && time > 0 ? time : defaultSlideTime;

        console.log(`[RabbitDebug] Slide ${index + 1} time calculation:`, {
          slideIndex: index + 1,
          frontmatterSlideTime: slideTime,
          frontmatterExists: slideTime !== undefined,
          parsedSlideTime: slideTime !== undefined ? parseFloat(slideTime) : null,
          defaultSlideTimeUsed: slideTime === undefined,
          finalTimeMinutes: finalTime,
          calculation: slideTime !== undefined
            ? `slideTime(${slideTime}) -> ${finalTime}`
            : `defaultSlideTime(${defaultSlideTime}) -> ${finalTime}`
        });

        return finalTime;
      });

      console.log('[RabbitDebug] Final slide times array:', times);
      console.log('[RabbitDebug] Total presentation time:', times.reduce((sum, time) => sum + time, 0), 'minutes');

      return times;
    },
    calculateTotalTime(slideTimes, defaultTime) {
      // If no slide times are specified, fallback to query time parameter
      const totalFromSlides = slideTimes.reduce((sum, time) => sum + time, 0);
      return totalFromSlides > 0 ? totalFromSlides : defaultTime;
    }
  },
  watch: {
    '$slidev.nav.currentPage': {
      immediate: true,
      handler(newPage) {
        const currentSlide = this.$slidev.nav.slides[newPage - 1];
        const currentSlideTime = currentSlide?.meta?.slide?.frontmatter?.time;
        console.log(`[RabbitDebug] Current slide #${newPage}:`, {
          frontmatter: currentSlide?.frontmatter,
          time: currentSlideTime,
          useSlideTimesEnabled: this.useSlideTimesEnabled
        });
      }
    }
  }
};
</script>
