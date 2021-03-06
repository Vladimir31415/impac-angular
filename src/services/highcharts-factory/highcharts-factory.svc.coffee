angular
.module('impac.services.highcharts-factory', [])
.factory('HighchartsFactory', ($filter)->

  templates =
    line: Object.freeze
      get: (series = [], options = {})->
        chart:
          type: 'line'
          zoomType: 'x'
          spacingTop: 20
        title: null
        credits:
          enabled: false
        legend:
          enabled: _.get(options, 'showLegend', true)
          layout: 'vertical'
          align: 'left'
          verticalAlign: 'middle'
        yAxis:
          title: null
          startOnTick: true
          minPadding: 0
        series: series
        rangeSelector:
          buttons: [
            { type: 'month', count: 4, text: 'def.' },
            { type: 'month', count: 1, text: '1m' },
            { type: 'month', count: 3, text: '3m' },
            { type: 'month', count: 6, text: '6m' },
            { type: 'year', count: 1, text: '1y' },
            { type: 'all', text: 'All' }
          ]
          selected: 0

  class Chart
    constructor: (@id, @data = {}, @options = {})->
      @_template = templates[@options.chartType]
      return

    render: (data, options)->
      @data = data if _.isObject(data)
      angular.extend(@options, options)
      chartConfig = angular.merge({}, @template(), @formatters(), @todayMarker())
      if _.isEmpty(@hc)
        @hc = Highcharts.stockChart(@id, chartConfig)
      else
        @hc.update(chartConfig)
      return @

    template: ->
      @_template.get(@data.series, @options)

    formatters: ->
      currency = @options.currency
      xAxis:
        labels:
          formatter: ->
            moment.unix(this.value / 1000).format('Do MMM YYYY')
      yAxis:
        labels:
          formatter: ->
            $filter('mnoCurrency')(this.value, currency, false, 0)
      tooltip:
        shared: false
        formatter: ->
          date = moment.unix(this.x / 1000).format('Do MMM YYYY')
          amount = $filter('mnoCurrency')(this.y, currency, false)
          name = this.series.name
          # If point is in the past, "My Projected Stuff" => "My Stuff"
          if moment.unix(this.x / 1000) < moment.utc().startOf('day')
            name = _.startCase _.trim name.toLowerCase().replace(/\s*projected\s*/, ' ')
          "<strong>#{date}</strong><br>#{name}: #{amount}"

    todayMarker: ->
      return {} unless @options.showToday
      xAxis:
        plotLines: [{
          color: _.get(@options, 'todayMarkerColor', 'rgba(0, 85, 255, 0.2)')
          value: moment.utc().startOf('day').unix() * 1000
          width: 1
          label:
            text: null
            verticalAlign: 'top'
            textAlign: 'center'
            rotation: 0
            y: -5
        }]

    addThreshold: (thresholdOptions)->
      return if _.isEmpty(@hc)
      # Initialize data matrix
      data = angular.copy @data.series[0].data
      for vector in data
        # When in the past, set y-axis value at null
        if !thresholdOptions.fullLengthThresholds && moment.unix(vector[0] / 1000) < moment.utc().startOf('day')
          vector[1] = null
        # When in the future, set y-axis value at thresholdOptions.value
        else
          vector[1] = parseFloat(thresholdOptions.value)
      # Build & add threshold serie
      threshold = angular.extend(
        { data: data, showInLegend: false, marker: { enabled: false } },
        thresholdOptions
      )
      @hc.addSeries(threshold)

    removeThreshold: (kpiId)->
      thresholdSerie = @findThreshold(kpiId)
      thresholdSerie.remove() if thresholdSerie?

    findThreshold: (kpiId)->
      _.find(@hc.series, (s)-> s.options.kpiId == kpiId)

    addThresholdEvent: (thresholdSerie, eventName, callback)->
      return unless thresholdSerie? && eventName? && _.isFunction(callback)
      Highcharts.addEvent(thresholdSerie, eventName, (_event)-> callback(thresholdSerie))

    # Extend default chart formatters to add custom legend img icon
    addCustomLegend: (formatterCallback, useHTML = true) ->
      @hc.legend.update({
        useHTML: useHTML
        labelFormatter: formatterCallback
      })

    # Adds events to series objects
    addSeriesEvent: (eventName, callback) ->
      return if _.isEmpty(@hc)
      eventHash = {}
      eventHash[eventName] = callback
      @hc.update({
        plotOptions:
          series:
            events: eventHash
      })
      return @hc
)
