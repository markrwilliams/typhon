import "unittest" =~ [=> unittest]
import "lib/tubes" =~ [=> Drain]
exports ()

def testMakeProcessGetArguments(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [].asMap(), [].asMap())
    assert.equal(proc.getArguments(), [b`echo`, b`foo`])


def testMakeProcessGetEnvironment(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [b`bar` => b`1`], [].asMap())
    assert.equal(proc.getEnvironment(), [b`bar` => b`1`])


def testMakeProcessGetPID(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [].asMap(), [].asMap())
    # this dumb test shall stand until we can actually communicate with the thing
    assert.equal(proc.getPID() > 0, true)


def testInterruptAndTestWait(assert, => makeProcess):
    def proc := makeProcess(b`yes`, [b`yes`], [].asMap(), [].asMap())
    def processInformation := [proc.wait(), proc.wait()]
    when (promiseAllFulfilled(processInformation)) ->
        def completedProcessInformation := proc.wait()

        for pi in (processInformation + [completedProcessInformation]):
            assert.equal(pi.exitStatus(), 0)
            # TODO enum for signals
            assert.equal(pi.terminationSignal(), 2)

    proc.interrupt()


def testStdout(assert, => makeProcess):
    def received := [].diverge()

    object stdoutCollector as Drain:
        to receive(item):
            received.push(item)
        to flowStopped(reason):
            traceln(`stopped $reason`)
        to flowAborted(reason):
            traceln(`aborted $reason`)

    def proc := makeProcess(b`python`, [b`python`, b`/tmp/xx.py`], [].asMap(),
                                       ["stdout" => stdoutCollector])

    when (proc.wait()) ->
        traceln(`stdout got: $received`)


unittest([testMakeProcessGetArguments,
          testMakeProcessGetEnvironment,
          testMakeProcessGetPID,
          testInterruptAndTestWait,
          testStdout])
