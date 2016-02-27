import "unittest" =~ [=> unittest]
exports ()

def testMakeProcessGetArguments(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [].asMap())
    assert.equal(proc.getArguments(), [b`echo`, b`foo`])


def testMakeProcessGetEnvironment(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [b`bar` => b`1`])
    assert.equal(proc.getEnvironment(), [b`bar` => b`1`])


def testMakeProcessGetPID(assert, => makeProcess):
    def proc := makeProcess(b`echo`, [b`echo`, b`foo`], [].asMap())
    # this dumb test shall stand until we can actually communicate with the thing
    assert.equal(proc.getPID() > 0, true)


def testInterruptAndTestWait(assert, => makeProcess):
    def proc := makeProcess(b`yes`, [b`yes`], [].asMap())
    def processInformation := [proc.wait(), proc.wait()]
    when (promiseAllFulfilled(processInformation)) ->
        def completedProcessInformation := proc.wait()

        for pi in (processInformation + [completedProcessInformation]):
            assert.equal(pi.exitStatus(), 0)
            # TODO enum for signals
            assert.equal(pi.terminationSignal(), 2)

    proc.interrupt()


unittest([testMakeProcessGetArguments,
          testMakeProcessGetEnvironment,
          testMakeProcessGetPID,
          testInterruptAndTestWait])
