<template>
  <!-- when exporting, this footer isn't exported -->
  <footer v-if="$route.query.print !== null" class="rablte-container">
    <!-- Race track container with proper spacing -->
    <div class="race-track">
      <!-- Lanes container with spacing for first/last tick visibility -->
      <div class="lanes">
        <!-- Rabbit lane -->
        <div class="rabbit-lane">
          <Rabbit :current="$slidev.nav.currentPage" :slide-times="slideTimes"
            :use-slide-times-enabled="useSlideTimesEnabled" :turtle-elapsed-time="turtleElapsedTime"
            :total-time-minutes="totalTimeMinutes" :debug-enabled="debugEnabled" />
        </div>

        <!-- Divider line with optional tick marks and time labels -->
        <div class="lane-divider">
          <div v-if="showSlideMarkers" class="slide-tick-marks">
            <!-- Add starting tick at 0% -->
            <div class="slide-tick start-tick" :style="{ left: '0%' }" title="Start"></div>
            <div v-for="(slidePosition, index) in slideMarkerPositions" :key="index" class="slide-tick"
              :style="{ left: slidePosition + '%' }" :title="`Slide ${index + 1}`"></div>
          </div>
          <!-- Time labels between tick marks -->
          <div v-if="showSlideMarkers && showSlideTimeLabels && slideTimes.length > 0" class="slide-time-labels">
            <div v-for="(timeLabel, index) in slideTimeLabels" :key="`time-${index}`" class="slide-time-label"
              :style="{ left: timeLabel.position + '%' }" :title="`${timeLabel.minutes}m for slide ${index + 1}`">
              {{ timeLabel.display }}
            </div>
          </div>
        </div>

        <!-- Turtle lane -->
        <div class="turtle-lane">
          <Turtle :current="$slidev.nav.currentPage" :total-time="totalTimeMinutes" :debug-enabled="debugEnabled"
            @elapsed-time-update="handleTurtleTimeUpdate" />
        </div>
      </div>

      <!-- Finish area -->
      <div class="finish-area">
        <Flag :slide-times="slideTimes" :total-time-minutes="totalTimeMinutes"
          :turtle-elapsed-time="turtleElapsedTime" />
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

    const showSlideMarkers = this.$slidev.configs?.rabbit?.showSlideMarkers ?? false;
    const showSlideTimeLabels = this.$slidev.configs?.rabbit?.showSlideTimeLabels ?? true;
    const slideMarkerPositions = this.calculateSlideMarkerPositions(slideTimes);
    const slideTimeLabels = this.calculateSlideTimeLabels(slideTimes, slideMarkerPositions);
    const debugEnabled = this.$slidev.configs?.rabbit?.debug ?? false;

    const lastTickPosition = slideMarkerPositions.length > 0 ? slideMarkerPositions[slideMarkerPositions.length - 1] : 100;

    if (debugEnabled) {
      console.log('[RabbitDebug] Configuration:', {
        useSlideTimesEnabled,
        totalTimeMinutes,
        hasSlideTimes: slideTimes.length > 0 && slideTimes.some(time => time > 0),
        slideTimes,
        rabbitConfig: this.$slidev.configs.rabbit,
        showSlideMarkers,
        showSlideTimeLabels,
        slideMarkerPositions,
        slideTimeLabels,
        lastTickPosition
      });
    }

    return {
      slideTimes,
      totalTimeMinutes,
      useSlideTimesEnabled,
      hasSlideTimes: slideTimes.length > 0 && slideTimes.some(time => time > 0),
      showSlideMarkers,
      showSlideTimeLabels,
      slideMarkerPositions,
      slideTimeLabels,
      turtleElapsedTime: 0,
      debugEnabled,
      lastTickPosition
    }
  },
  methods: {
    getSlideTimes() {
      // Get all slides and extract time from frontmatter
      const slides = this.$slidev.nav.slides;
      const defaultSlideTime = this.$slidev.configs?.rabbit?.defaultSlideTime || 2; // Default to 2 minutes if not configured

      if (this.debugEnabled) {
        console.log('[RabbitDebug] Get slides object:', slides);
        console.log('[RabbitDebug] Default slide time configuration:', {
          configuredValue: this.$slidev.configs?.rabbit?.defaultSlideTime,
          effectiveDefault: defaultSlideTime,
          rabbitConfig: this.$slidev.configs?.rabbit
        });
      }

      const times = slides.map((slide, index) => {
        // Priority: 1. slideTime frontmatter, 2. defaultSlideTime config, 3. hardcoded 2 minutes
        const slideTime = slide.meta.slide.frontmatter?.slideTime;
        const time = slideTime !== undefined ? parseFloat(slideTime) : defaultSlideTime;
        const finalTime = !isNaN(time) && time > 0 ? time : defaultSlideTime;

        if (this.debugEnabled) {
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
        }

        return finalTime;
      });

      if (this.debugEnabled) {
        console.log('[RabbitDebug] Final slide times array:', times);
        console.log('[RabbitDebug] Total presentation time:', times.reduce((sum, time) => sum + time, 0), 'minutes');
      }

      return times;
    },
    calculateTotalTime(slideTimes, defaultTime) {
      // If no slide times are specified, fallback to query time parameter
      const totalFromSlides = slideTimes.reduce((sum, time) => sum + time, 0);
      return totalFromSlides > 0 ? totalFromSlides : defaultTime;
    },
    calculateSlideMarkerPositions(slideTimes) {
      const useSlideTimesEnabled = this.$slidev.configs?.rabbit?.useSlideTimes ?? false;
      const totalSlides = this.$slidev.nav.total;

      if (useSlideTimesEnabled && slideTimes.length > 0) {
        // Time-based positioning: position markers based on cumulative time
        const totalTime = slideTimes.reduce((sum, time) => sum + time, 0);
        let accumulatedTime = 0;

        return slideTimes.map((time, index) => {
          accumulatedTime += time;
          const position = (accumulatedTime / totalTime) * 100;
          if (this.debugEnabled) {
            console.log(`[RabbitDebug] Slide ${index + 1} marker position: ${position.toFixed(2)}% (${accumulatedTime}/${totalTime} minutes)`);
          }
          return position;
        });
      } else {
        // Slide-count-based positioning: evenly space markers
        const positions = [];
        for (let i = 1; i <= totalSlides; i++) {
          const position = (i / totalSlides) * 100;
          positions.push(position);
          if (this.debugEnabled) {
            console.log(`[RabbitDebug] Slide ${i} marker position: ${position.toFixed(2)}% (slide-count-based)`);
          }
        }
        return positions;
      }
    },
    calculateSlideTimeLabels(slideTimes, slideMarkerPositions) {
      if (!slideMarkerPositions || slideMarkerPositions.length === 0) {
        return [];
      }

      return slideTimes.map((time, index) => {
        let position;

        if (index === 0) {
          // First segment: from 0% to first tick mark
          position = slideMarkerPositions[0] / 2;
        } else {
          // Subsequent segments: from previous tick mark to current tick mark
          const prevPosition = slideMarkerPositions[index - 1];
          const currentPosition = slideMarkerPositions[index];
          position = prevPosition + (currentPosition - prevPosition) / 2;
        }

        // Format time display - handle fractional minutes
        let display;
        if (time % 1 === 0) {
          // Whole numbers: show as integer
          display = `${Math.floor(time)}`;
        } else if (time < 1) {
          // Less than 1 minute: show as decimal
          display = time.toFixed(2).replace(/\.?0+$/, '');
        } else {
          // Mixed: show with minimal decimal places
          display = time.toFixed(1).replace(/\.0$/, '');
        }

        if (this.debugEnabled) {
          console.log(`[RabbitDebug] Slide ${index + 1} time label: ${display} (${time}m) at ${position.toFixed(2)}%`);
        }

        return { position, minutes: time, display };
      });
    },
    handleTurtleTimeUpdate(elapsedTime) {
      this.turtleElapsedTime = elapsedTime;
      if (this.debugEnabled) {
        console.log('[RabbitDebug] Turtle elapsed time updated:', elapsedTime);
      }
    }
  },
  watch: {
    '$slidev.nav.currentPage': {
      immediate: true,
      handler(newPage) {
        if (this.debugEnabled) {
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
  }
};
</script>
