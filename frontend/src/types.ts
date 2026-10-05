export type Connection = {state:string;message:string}
export type Scenario = {name:string;subtitle:string;description:string;currency:string;date_range:string[];suggestions:string[];metrics:Record<string,string>}
export type Table = {columns:string[];rows:Record<string,string|number|null>[];row_count:number;truncated:boolean}
export type ChartSpec = {type:'bar'|'line'|'pie';dimension:string;measures:string[]}
export type ChatResult = {kind:'query'|'message'|'clarify';answer:string;sql:string|null;table:Table|null;analysis:string|null;chart:ChartSpec|null;warnings:string[]}
