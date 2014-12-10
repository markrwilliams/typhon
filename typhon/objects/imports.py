# Copyright (C) 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy
# of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

from typhon.atoms import getAtom
from typhon.env import Environment, finalize
from typhon.errors import Refused
from typhon.objects.constants import NullObject
from typhon.objects.data import StrObject
from typhon.objects.root import Object
from typhon.importing import evaluateTerms, obtainModule

RUN_1 = getAtom(u"run", 1)


class Import(Object):

    def __init__(self, scope, recorder):
        self.scope = scope
        self.recorder = recorder

    def recv(self, atom, args):
        if atom is RUN_1:
            path = args[0]
            if not isinstance(path, StrObject):
                raise Refused(RUN_1, args)

            p = path.getString().encode("utf-8")
            p += ".ty"

            # Attempt the import.
            terms = obtainModule(p, self.recorder)

            # Get results.
            env = Environment(finalize(self.scope), None)
            with self.recorder.context("Time spent in vats"):
                result = evaluateTerms(terms, env)

            if result is None:
                print "Result was None :c"
                return NullObject
            return result

        raise Refused(atom, args)


def addImportToScope(scope, recorder):
    scope[u"import"] = Import(scope.copy(), recorder)