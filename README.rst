======
Typhon
======

Typhon is a virtual machine for Monte. It loads and executes Kernel-Monte from
Monte AST files.

How To Monte
============

You will need RPython from Mercurial::

    $ hg clone https://bitbucket.org/pypy/pypy
    $ export PYTHONPATH=pypy:.

Typhon operates in both untranslated and translated modes, with an optional
JIT. Regardless of mode of operation, you'll need some dependencies (Twisted
and RPython), so create a virtualenv::

    $ virtualenv local-typhon -p pypy
    $ . local-typhon/bin/activate
    $ pip install -r requirements.txt

If you don't have a system PyPy, you can leave off ``-p pypy``, but be warned
that this will increase run times. Once that's done, Typhon can be run
untranslated::

    $ python main.py your/awesome/script.ty

Translation is done via the RPython toolchain::

    $ python -m rpython -O2 main

The JIT can be enabled with a switch::

    $ python -m rpython -Ojit main

You can also build a slow version with libgc, for testing purposes::

    $ python -m rpython -O0 main

The resulting executable is immediately usable for any scripts that don't use
prelude features::

    $ ./mt-typhon your/awesome/script.ty

Note that translation is not cheap. It will require approximately 0.5GiB
memory and 2min CPU time on a 64-bit x86 system to translate a non-JIT Typhon
executable, or 1GiB memory and 9min CPU time with the JIT enabled.

MAST Prelude
============

Without a prelude, Typhon doesn't do much. Most Monte applications have a
reasonable expectation of certain non-kernel features, which are implemented
in Monte via a prelude and library.

Fortunately, Typhon comes with a self-hosting Monte compiler and a prebuilt
prelude, in the ``boot`` directory. To use it::

    $ ./mt-typhon -l boot script.ty

And the rest of the MAST library can be built immediately::

    $ make mast

Then, you can use the newly built prelude and library::

    $ ./mt-typhon -l mast another/awesome/script.ty

Contributing
============

Contributions are welcome. Please ensure that you're okay with the license!

Unit tests are tested by Travis. You can run them yourself; I recommend the
Trial test runner::

    $ trial typhon

Diffing Typhon Binaries
-----------------------

By default, git won't show diffs of binary files. I don't especially blame it.
However, with a bit of a filter, we can give git what it needs::

    $ git config diff.typhon.textconv ./dump.py

This configuration option, along with the ``.gitattributes`` in the
repository, will let git display textual diffs of the binary ASTs.

RPython Quirks
--------------

Here's what you need to know about RPython and things imported from
``rpython.rlib``.

Immutability
~~~~~~~~~~~~

Like Monte, RPython values immutable structures. Whenever a class is
immutable, adding the ``_immutable_ = True`` annotation will cause RPython to
enforce an immutability variant: The fields of an instance of that class can
only be assigned to once.

It's possible to make only some fields immutable; just list all the immutable
fields in a tuple with ``_immutable_fields_ = "this", "that"``. To make a
field an immutable list with immutable elements, use a ``[*]``, as in
``_immutable_fields_ = "this", "that", "those[*]"``.

The JIT (``rpython.rlib.jit``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``r.r.jit`` is mostly about hints to inform the JIT about the behavior of code
paths. Some hints are safe and some are not safe.

The JIT colors all values as "red" or "green"; a red value is non-constant and
a green value is constant. ``promote`` accepts a red value and turns it into a
green value. The JIT will reflect this with a guard on the value of the given
object. When a value is expected to have a relatively small number of
possibilities, a ``promote`` can be very effective at improving the
performance of the code. ``promote`` is safe; it will never cause the JIT to
generate wrong code, although it can cause the JIT to perform too much
compilation.

``jit_debug()`` can print one string and up to four integers to the JIT log.
The computation which prepares the debug message is part of the JIT trace, so
it is ideal to have the inputs be green values.

``elidable`` functions must be referentially transparent. In return, the JIT
accepts the promise of referential transparency and will try to reorder or
remove the call to the ``elidable`` function when it can. The function need
not actually be pure; it is sufficient for it to appear pure in all cases. If
the function is not pure, then ``elidable`` is unsafe, since the JIT will not
second-guess a promise of elidability.

.. note::
    Do *not* mark ``elidable`` if you want the JIT to inline the function. The
    JIT will not enter an ``elidable`` function.

``elidable_promote`` changes a function so that it is ``elidable`` and all of
its arguments will be ``promote``'d before entering the function body. It is
unsafe, like ``elidable``.

``dont_look_inside`` forces the JIT to not inline calls to a function. It is
sometimes necessary to protect events like GIL handling or I/O. It can also be
a big improvement for calls to functions which don't inline well due to
recursive or other strange behavior. It should be safe.

``unroll_safe`` forces the JIT to consider inlining calls to functions which
were not inlinable due to containing loops. This is important because the JIT
will otherwise refuse to look inside those functions. Usage of ``unroll_safe``
is an informal promise to the JIT that the loops in the function are tightly
bounded in the number of iterations which will be performed. While not unsafe,
``unroll_safe`` can cause exponential amounts of overcompilation and
overtracing, so it should be used sparingly.

How are these used within the codebase? Values that are expected to be green
but aren't green-inferred by the JIT are ``promote``'d. Functions that do I/O
have ``dont_look_inside``. Functions which are pure and called often are
``elidable``. Lots of factoring has been done to make small chunks of code
``elidable``.

If a function has a loop that is conditionally called, it is useful to factor
the loop to a separate function and then consider whether to mark the new
function with ``unroll_safe``. Even if the function isn't actually safe to
unroll, merely the factorization of code is sufficient to allow the JIT to
look into the original function. This happens with every object which is
defined in RPython; the dispatch function, ``callAtom()`` or similar, is
factored to not have loops within it. Since atoms are (usually) green values
during execution, this means that ``callAtom()`` gets specialized for that
atom, and the actual work can usually be inlined.

Unicode (``rpython.rlib.unicodedata``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We use RPython's Unicode database. The magic incantation::

    from rpython.rlib.unicodedata import unicodedb_6_2_0 as unicodedb

``unicodedb`` will have plenty of useful functions, like ``islower()`` and
``isalpha()``. These functions are *not* available as methods on ``unicode``
objects.

.. _reference Monte: https://github.com/monte-language/monte

Documentation
-------------

If you create a new object by subclassing ``Object`` or calling ``@runnable``,
please give it a docstring. The docstrings will be reflected into Monte, so
please follow these guidelines:

* The first line should describe the object.
* Subsequent lines should describe specifics of the object's nature which
  might be helpful to somebody calling ``help()`` on the object.
* Docstrings should refer to their object as "this object".
* In-jokes are sometimes allowed. Ask on IRC.
* Dry language is always allowed.
* Unicode is encouraged; do not be afraid to use symbols which are generally
  available in Unicode fonts. Ask on IRC if unsure.

An example:

    ▲> help(Any)
    Result: Object type: AnyGuard
    A guard which admits the universal set.
    This object specializes to a guard which admits the union of its
    subguards: Any[X, Y, Z] =~ X ∪ Y ∪ Z

Also document objects and methods written in Monte. For methods:

* "this method" is the correct self-reference.
* To refer to names defined in the method specification, surround the name in
  backticks.
* To refer to methods, use atom syntax and backticks: A method with name
  "meth" and arity 2 would appear as \`meth/2\`.

Autohelp would like to remind you that subclasses of ``Object`` should
decorate themselves with ``@autohelp`` in order to maintain compliance and
safety.

To override pretty-printing for an object, add a ``toString()`` method which
should return a Unicode string.
