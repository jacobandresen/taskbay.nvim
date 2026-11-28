// Data-driven probe of the subagent guard in agents/pi/extension.ts, loaded by pi with -e.
// PROBE_CASES: a JSON file with [{ name, input }]; "$MODEL" and "$CWD" in input values become the
// session's model and working directory. PROBE_OUT receives
// { schema: { top, options }, results: [{ name, verdict: "block" | "allow", runs }] }, where runs is
// what pi-subagents would run with (flattenSubagentToolOptions), or "rejected: <reason>".
import { readFileSync, writeFileSync } from "node:fs";
import extension from "../../agents/pi/extension.ts";
import { SubagentParams, SUBAGENT_OPTION_KEYS } from "../../agents/pi/node_modules/pi-subagents/src/extension/schemas.js";
import { flattenSubagentToolOptions } from "../../agents/pi/node_modules/pi-subagents/src/extension/subagent-options.js";

export default async function (pi: any) {
  const handlers = new Map<string, Function[]>();
  await extension({ ...pi, registerTool() {}, registerCommand() {}, registerShortcut() {},
    on(event: string, handler: Function) { handlers.set(event, [...(handlers.get(event) ?? []), handler]); } });
  pi.on("session_start", async (event: any, ctx: any) => {
    const invoke = (name: string, value: object = {}) => handlers.get(name)![0](value, ctx);
    await invoke("session_start", event);
    const model = `${ctx.model.provider}/${ctx.model.id}`;
    const fill = (value: unknown): unknown =>
      value === "$MODEL" ? model : value === "$CWD" ? ctx.cwd
        : Array.isArray(value) ? value.map(fill)
        : value && typeof value === "object" ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, fill(v)]))
        : value;
    const cases = process.env.PROBE_CASES ? JSON.parse(readFileSync(process.env.PROBE_CASES, "utf8")) : [];
    const results = [];
    for (const { name, input, tool } of cases) {
      const filled = fill(input) as Record<string, unknown>;
      const blocked = (await invoke("tool_call", { toolName: tool ?? "subagent", input: filled }))?.block === true;
      let runs: unknown;
      try { runs = flattenSubagentToolOptions(filled); } catch (error: any) { runs = "rejected: " + error.message; }
      results.push({ name, verdict: blocked ? "block" : "allow", runs });
    }
    const schema = { top: Object.keys((SubagentParams as any).properties), options: [...SUBAGENT_OPTION_KEYS] };
    writeFileSync(process.env.PROBE_OUT!, JSON.stringify({ schema, results }));
  });
}
