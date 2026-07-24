export const meta = {
  name: 'ticket-execute',
  description: 'Run a spec task queue sequentially through task-runner, one task at a time',
  phases: [{ title: 'Execute' }],
}

// Expects `args` = { specDir, ceiling, modelOverride, tasks, pluginRoot },
// where tasks is an array of { id, phase, rating, description } parsed from
// build-task-queue.sh's TASK: lines (rating is easy|standard|hard, default
// standard), ceiling is models.ceiling from autocode.yml (default opus),
// modelOverride is the ticket skill's optional MODEL_OVERRIDE (M4; null or
// absent when not given), and pluginRoot is the caller's resolved
// $AUTOCODE_PLUGIN_ROOT.
//
// Model selection: the task-runner is spawned with NO model parameter, so
// its sonnet frontmatter governs the orchestration itself; RATING/CEILING
// (and MODEL only when overridden) go in the prompt and the task-runner
// resolves each sub-agent spawn via the C table in docs/MODEL_SELECTION.md.
//
// Tasks run strictly sequentially (not pipeline()/parallel()) because they
// share one working tree - concurrent task-runner agents editing the same
// repo would risk clobbering each other's work. The only thing this buys
// over the old inline execute loop is moving the whole multi-task
// transcript out of the calling session's context into one background run.
//
// On a task-specific failure, remaining tasks in the same phase are marked
// skipped (dependency order within a phase means later tasks likely build
// on the failed one). Cross-phase dependents are not detected - that
// judgment call is left to the human reviewing the final report. A
// "setup" category failure aborts the whole queue, since an environment
// problem will hit every remaining task identically.

const { specDir, ceiling, modelOverride, tasks, pluginRoot } = args

// task-runner shells out to $AUTOCODE_PLUGIN_ROOT/scripts/... internally
// (test commands, plugin scripts, git rollback). A background Workflow
// subagent is a fresh process and is not guaranteed to inherit this
// session's env, so make the var self-healing rather than assume it's set.
const envNote = pluginRoot
  ? `\n\nIMPORTANT: the autocode plugin root is ${pluginRoot}. If \`$AUTOCODE_PLUGIN_ROOT\` is empty in your shell, ` +
    `set it inline on the same command line (e.g. \`AUTOCODE_PLUGIN_ROOT=${pluginRoot} bash ${pluginRoot}/scripts/<script>.sh ...\`).`
  : ''

const skipPhases = new Set()
const results = []

log(`Starting queue: ${tasks.length} task(s)`)

for (const task of tasks) {
  if (skipPhases.has(task.phase)) {
    results.push({ id: task.id, phase: task.phase, status: 'skipped' })
    continue
  }

  log(`${task.id} (${task.phase}): ${task.description}`)

  const output = await agent(
    `Execute task\n\nSPEC_DIR=${specDir}\nTASK=[${task.id}] ${task.description}\nTASK_ID=${task.id}\nRATING=${task.rating || 'standard'}\nCEILING=${ceiling || 'opus'}` +
      (modelOverride ? `\nMODEL=${modelOverride}` : '') +
      `\n\nRun full write-tests -> red -> code -> green -> analyze -> refactor loop for this task. Output structured completion status when done.` +
      envNote,
    { agentType: 'autocode:task-runner', phase: 'Execute', label: task.id }
  )

  const text = typeof output === 'string' ? output : JSON.stringify(output ?? '')
  const completed = text.match(/<task-completed task="[^"]*" status="completed" type="([^"]*)"\s*\/>/)
  const failed = text.match(/<task-completed task="[^"]*" status="failed" category="([^"]*)" retryable="([^"]*)" reason="([^"]*)"\s*\/>/)

  if (completed) {
    results.push({ id: task.id, phase: task.phase, status: 'completed', type: completed[1] })
    log(`${task.id} done (${results.filter(r => r.status === 'completed').length}/${tasks.length} completed so far)`)
  } else if (failed) {
    const category = failed[1]
    const retryable = failed[2] === 'true'
    results.push({ id: task.id, phase: task.phase, status: 'failed', category, retryable, reason: failed[3] })
    if (category === 'setup') {
      log(`Setup failure on ${task.id} - stopping queue entirely (environment problem would hit every remaining task)`)
      break
    }
    log(`${task.id} failed (category=${category}) - skipping remaining tasks in ${task.phase}`)
    skipPhases.add(task.phase)
  } else {
    results.push({ id: task.id, phase: task.phase, status: 'failed', category: 'unknown', retryable: false, reason: 'no <task-completed> tag in output' })
    log(`${task.id} produced no <task-completed> tag - treating as failed, skipping remaining tasks in ${task.phase}`)
    skipPhases.add(task.phase)
  }
}

const completedCount = results.filter(r => r.status === 'completed').length
const failedCount = results.filter(r => r.status === 'failed').length
const skippedCount = results.filter(r => r.status === 'skipped').length
log(`Queue done: ${completedCount} completed, ${failedCount} failed, ${skippedCount} skipped`)

return { results }
