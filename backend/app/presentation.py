"""Constrained presentation metadata derived exclusively from returned SQL rows."""
import math
import re
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, ValidationError


class ChartSpec(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    type: Literal['bar', 'line', 'pie']
    dimension: str
    measures: list[str] = Field(min_length=1, max_length=4)


def analysis_requested(question: str, history: list) -> bool:
    text = question.lower()
    if re.search(r"\b(no|without)\s+(?:any\s+|business\s+)?analysis\b|\b(?:do not|don't|dont)\s+analy[sz]e\b|\b(?:data|table|numbers|results)\s+only\b|(?:不要|无需|不需要)(?:进行|做|业务)?分析|仅.*(?:数据|表格)|只.*(?:数据|表格)", text):
        return False
    if re.search(r'\b(analy[sz]e|analysis|interpret\w*|recommend\w*|explain\w*|why|insight\w*|advice|suggest\w*)\b|分析|解读|解释|为什么|为何|原因|建议|启示', text):
        return True
    # Elliptical follow-ups retain analysis intent only with an actual prior topic.
    return bool(history and re.search(r'\b(?:what does (?:this|that|it) mean|what should we do|how to improve|tell me more)\b|意味着什么|怎么办|如何改善|展开说|详细说', text))


def validate_chart(candidate: dict, table: dict) -> dict | None:
    try:
        spec = ChartSpec.model_validate(candidate)
    except (ValidationError, TypeError):
        return None
    columns, rows = table['columns'], table['rows']
    if len(rows) < 2 or spec.dimension not in columns or len(set(spec.measures)) != len(spec.measures):
        return None
    if any(m not in columns or m == spec.dimension for m in spec.measures):
        return None
    labels = [r.get(spec.dimension) for r in rows]
    if any(not isinstance(x, (str, int, float)) or isinstance(x, bool) or (isinstance(x, float) and not math.isfinite(x)) for x in labels):
        return None
    if len({str(x) for x in labels}) != len(labels):
        return None
    for measure in spec.measures:
        if any(not isinstance(r.get(measure), (int, float)) or isinstance(r.get(measure), bool) or not math.isfinite(r[measure]) for r in rows):
            return None
    if spec.type == 'pie':
        if len(spec.measures) != 1 or len(rows) > 12:
            return None
        values = [r[spec.measures[0]] for r in rows]
        if min(values) < 0 or not math.isfinite(sum(values)) or sum(values) <= 0:
            return None
    return spec.model_dump()


def choose_chart(question: str, table: dict) -> dict | None:
    rows, columns = table['rows'], table['columns']
    if len(rows) < 2:
        return None
    numeric = [c for c in columns if all(isinstance(r.get(c), (int, float)) and not isinstance(r.get(c), bool) and math.isfinite(r[c]) for r in rows)]
    dimensions = [c for c in columns if c not in numeric]
    temporal = [c for c in columns if re.search(r'date|month|year|week|day|quarter|日期|月份|年份', c, re.I)]
    dimension = temporal[0] if temporal else dimensions[0] if len(dimensions) == 1 else None
    if dimension is None or len(dimensions) > 1:
        return None
    measures = [c for c in numeric if c != dimension]
    if not measures:
        return None
    # The result has no trusted unit metadata. Plot only the first measure so
    # revenue, quantities and percentages cannot share a misleading axis.
    measures = measures[:1]
    text = question.lower()
    if re.search(r'\b(pie|share|proportion|composition)\b|饼图|占比|份额|构成', text):
        kind = 'pie'
    elif re.search(r'\b(bar|column)\b|柱状|条形', text):
        kind = 'bar'
    elif temporal or re.search(r'\b(line|trend|over time)\b|折线|趋势', text):
        kind = 'line'
    else:
        kind = 'bar'
    candidate = {'type': kind, 'dimension': dimension, 'measures': measures}
    valid = validate_chart(candidate, table)
    if not valid and kind == 'pie':
        candidate['type'] = 'bar'
        valid = validate_chart(candidate, table)
    return valid
