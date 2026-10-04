export type Connection = {state:string;message:string}
export type Scenario = {name:string;subtitle:string;description:string;currency:string;date_range:string[];suggestions:string[];metrics:Record<string,string>}
export type Table = {columns:string[];rows:Record<string,string|number|null>[];row_count:number;truncated:boolean}
// Extension point: CodeArts Agent should introduce a typed ChartSpec here.
export type ChatResult = {kind:'query'|'message'|'clarify';answer:string;sql:string|null;table:Table|null;analysis:string|null;chart:null;warnings:string[]}
