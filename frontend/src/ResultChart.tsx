import { useEffect, useRef, useState } from 'react'
import { init, use, type EChartsCoreOption } from 'echarts/core'
import { BarChart, LineChart, PieChart } from 'echarts/charts'
import { GridComponent, LegendComponent, TooltipComponent, AriaComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import type { ChartSpec, Table } from './types'

use([BarChart, LineChart, PieChart, GridComponent, LegendComponent, TooltipComponent, AriaComponent, CanvasRenderer])

export function ResultChart({ spec, table, language }: { spec: ChartSpec; table: Table; language: 'en'|'zh' }) {
  const host = useRef<HTMLDivElement>(null)
  const [failed, setFailed] = useState(false)
  useEffect(() => {
    setFailed(false)
    if (!host.current) return
    const chart = init(host.current)
    const rows = [...table.rows]
    // SQL's textual ISO dates/months sort chronologically; other query order is preserved.
    if (spec.type === 'line' && /month|year|week|day|quarter/i.test(spec.dimension) && rows.every(r => typeof r[spec.dimension] === 'number')) {
      rows.sort((a, b) => Number(a[spec.dimension]) - Number(b[spec.dimension]))
    } else if (spec.type === 'line' && rows.every(r => /^\d{4}(?:-\d{2})?(?:-\d{2})?$/.test(String(r[spec.dimension])))) {
      rows.sort((a, b) => String(a[spec.dimension]).localeCompare(String(b[spec.dimension])))
    }
    const labels = rows.map(r => String(r[spec.dimension]))
    const number = (n: unknown) => typeof n === 'number' ? new Intl.NumberFormat(language === 'zh' ? 'zh-CN' : 'en-SG', { maximumFractionDigits: 2 }).format(n) : String(n)
    const option: EChartsCoreOption = {
      color: ['#2866a1', '#52a49c', '#e6ab51', '#8a7db8'],
      aria: { enabled: true }, animation: !window.matchMedia('(prefers-reduced-motion: reduce)').matches,
      tooltip: { trigger: spec.type === 'pie' ? 'item' : 'axis', renderMode: 'richText', valueFormatter: number },
      legend: { bottom: 0, type: 'scroll' },
      ...(spec.type === 'pie' ? {
        series: [{ type: 'pie', radius: ['35%', '65%'], center: ['50%', '44%'], data: rows.map(r => ({ name: String(r[spec.dimension]), value: r[spec.measures[0]] })), label: { formatter: '{b}: {d}%' } }],
      } : {
        grid: { left: 20, right: 20, top: 24, bottom: 65, containLabel: true },
        xAxis: { type: 'category', data: labels, axisLabel: { hideOverlap: true, width: 100, overflow: 'truncate' } },
        yAxis: { type: 'value', axisLabel: { formatter: number } },
        series: spec.measures.map(name => ({ name, type: spec.type, data: rows.map(r => r[name]), ...(spec.type === 'bar' ? { barMaxWidth: 48 } : { smooth: false }) })),
      }),
    }
    try { chart.setOption(option) } catch { setFailed(true) }
    const observer = new ResizeObserver(() => chart.resize())
    observer.observe(host.current)
    return () => { observer.disconnect(); chart.dispose() }
  }, [spec, table, language])
  return <div className="chart-card"><div className="chart-heading">{language === 'zh' ? '数据图表' : 'Data visualization'}<span>{spec.measures.join(' · ')}</span></div>{failed && <p role="status">{language === 'zh' ? '无法显示图表，请查看数据表。' : 'Unable to display chart. View the table below.'}</p>}<div ref={host} className="result-chart" role="img" aria-label={`${spec.type}: ${spec.measures.join(', ')} by ${spec.dimension}`}/></div>
}
