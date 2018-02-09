r"""
Wrappers on GAP matrices
"""
#*****************************************************************************
#       Copyright (C) 2017 Vincent Delecroix <20100.delecroix@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

from __future__ import print_function, absolute_import

from sage.libs.gap.libgap import libgap
from . import matrix_space
from sage.structure.element cimport Matrix

cdef class Matrix_gap(Matrix_dense):
    r"""
    A Sage matrix wrapper over a GAP matrix.

    EXAMPLES::

        sage: M = MatrixSpace(ZZ, 2, implementation='gap')
        sage: m1 = M([1, 0, 2, -3])
        sage: m2 = M([2, 2, 5, -1])
        sage: type(m1)
        <type 'sage.matrix.matrix_gap.Matrix_gap'>

        sage: m1 * m2
        [  2   2]
        [-11   7]
        sage: type(m1 * m2)
        <type 'sage.matrix.matrix_gap.Matrix_gap'>

        sage: M = MatrixSpace(QQ, 5, 3, implementation='gap')
        sage: m = M(range(15))
        sage: m.left_kernel()
        Vector space of degree 5 and dimension 3 over Rational Field
        Basis matrix:
        [ 1  0  0 -4  3]
        [ 0  1  0 -3  2]
        [ 0  0  1 -2  1]

        sage: M = MatrixSpace(ZZ, 10, implementation='gap')
        sage: m = M(range(100))
        sage: m.transpose().parent() is M
        True

        sage: UCF = UniversalCyclotomicField()
        sage: M = MatrixSpace(UCF, 3, implementation='gap')
        sage: m = M([UCF.zeta(i) for i in range(1,10)])
        sage: m
        [               1               -1             E(3)]
        [            E(4)             E(5)          -E(3)^2]
        [            E(7)             E(8) -E(9)^4 - E(9)^7]
        sage: (m^2)[1,2]
        E(180)^32 - E(180)^33 + E(180)^68 - E(180)^69 + E(180)^104 - E(180)^141 - E(180)^156 + E(180)^176 - E(180)^177

    TESTS::

        sage: for ring in [ZZ, QQ, UniversalCyclotomicField(), GF(2), GF(3)]:
        ....:     M = MatrixSpace(ring, 2, implementation='gap')
        ....:     TestSuite(M).run()
        ....:     M = MatrixSpace(ring, 2, 3, implementation='gap')
        ....:     TestSuite(M).run()
    """
    def __init__(self, parent, entries, coerce, copy):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: M(0)
            [0 0]
            [0 0]
            sage: M(1)
            [1 0]
            [0 1]
            sage: M(2)
            [2 0]
            [0 2]
            sage: type(M(0))
            <type 'sage.matrix.matrix_gap.Matrix_gap'>
            sage: type(M(1))
            <type 'sage.matrix.matrix_gap.Matrix_gap'>
            sage: type(M(2))
            <type 'sage.matrix.matrix_gap.Matrix_gap'>

            sage: M = MatrixSpace(QQ, 2, 3, implementation='gap')
            sage: M(0)
            [0 0 0]
            [0 0 0]
            sage: M(1)
            Traceback (most recent call last):
            ...
            TypeError: identity matrix must be square

            sage: MatrixSpace(QQ, 1, 2)(0)
            [0 0]
            sage: MatrixSpace(QQ, 2, 1)(0)
            [0]
            [0]
        """
        Matrix_dense.__init__(self, parent)

        R = self._base_ring

        if isinstance(entries, (tuple, list)):
            entries = [[R(x) for x in entries[i * self._ncols: (i+1) * self._ncols]] for i in range(self._nrows)]
        else:
            zero = R.zero()
            if entries is None:
                elt = zero
            else:
                elt = R(entries)
            entries = [[zero] * self._ncols for i in range(self._nrows)]
            if not elt.is_zero():
                if self._nrows != self._ncols:
                    raise TypeError('non diagonal matrices can not be initialized from a scalar')
                for i in range(self._nrows):
                    entries[i][i] = elt

        self._libgap = libgap(entries)

    cdef Matrix_gap _new(self, Py_ssize_t nrows, Py_ssize_t ncols):
        if nrows == self._nrows and ncols == self._ncols:
            P = self._parent
        else:
            P = self.matrix_space(nrows, ncols)

        cdef Matrix_gap M = Matrix_gap.__new__(Matrix_gap, P, None, None, None)
        Matrix_dense.__init__(M, P)
        return M

    def __copy__(self):
        r"""
        TESTS::

            sage: M = MatrixSpace(QQ, 2, implementation='gap')
            sage: m1 = M([1,2,0,3])
            sage: m2 = m1.__copy__()
            sage: m2
            [1 2]
            [0 3]
            sage: m1[0,1] = -2
            sage: m1
            [ 1 -2]
            [ 0  3]
            sage: m2
            [1 2]
            [0 3]
        """
        cdef Matrix_gap M = self._new(self._nrows, self._ncols)
        M._libgap = self._libgap.deepcopy(1)
        return M

    def __reduce__(self):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: m = M([1,2,1,2])
            sage: loads(dumps(m)) == m
            True
        """
        return self._parent, (self.list(),)

    cpdef GapElement gap(self):
        r"""
        Return the underlying gap object.

        EXAMPLES::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: m = M([1,2,2,1]).gap()
            sage: m
            [ [ 1, 2 ], [ 2, 1 ] ]
            sage: type(m)
            <type 'sage.libs.gap.element.GapElement_List'>

            sage: m.MatrixAutomorphisms()
            Group([ (1,2) ])
        """
        return self._libgap

    cdef get_unsafe(self, Py_ssize_t i, Py_ssize_t j):
        return self._base_ring(self._libgap[i,j])

    cdef set_unsafe(self, Py_ssize_t i, Py_ssize_t j, object x):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: m = M(0)
            sage: m[0,1] = 13
            sage: m
            [ 0 13]
            [ 0  0]
            sage: m[1,0] = -1/2
            Traceback (most recent call last):
            ...
            TypeError: no conversion of this rational to integer
        """
        self._libgap[i,j] = x

    cpdef _richcmp_(self, other, int op):
        r"""
        Compare ``self`` and ``right``.

        EXAMPLES::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: m1 = M([1,2,3,4])
            sage: m2 = M([1,2,3,4])
            sage: m3 = M([1,2,0,4])
            sage: m1 == m2
            True
            sage: m1 != m2
            False
            sage: m1 == m3
            False
            sage: m1 != m3
            True

            sage: M = MatrixSpace(QQ, 2, implementation='gap')
            sage: m1 = M([1/2, 1/3, 2, -5])
            sage: m2 = M([1/2, 1/3, 2, -5])
            sage: m3 = M([1/2, 0, 2, -5])
            sage: m1 == m2
            True
            sage: m1 != m2
            False
            sage: m1 == m3
            False
            sage: m1 != m3
            True

            sage: UCF = UniversalCyclotomicField()
            sage: M = MatrixSpace(UCF, 2, implementation='gap')
            sage: m1 = M([E(2), E(3), 0, E(4)])
            sage: m2 = M([E(2), E(3), 0, E(4)])
            sage: m3 = M([E(2), E(3), 0, E(5)])
            sage: m1 == m2
            True
            sage: m1 != m2
            False
            sage: m1 == m3
            False
            sage: m1 != m3
            True
        """
        return (<Matrix_gap> self)._libgap._richcmp_((<Matrix_gap> other)._libgap, op)

    def __neg__(self):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, 3, implementation='gap')
            sage: m = M([1, -1, 3, 2, -5, 1])
            sage: -m
            [-1  1 -3]
            [-2  5 -1]
        """
        cdef Matrix_gap M = self._new(self._nrows, self._ncols)
        M._libgap = self._libgap.AdditiveInverse()
        return M

    def __invert__(self):
        r"""
        TESTS::

            sage: M = MatrixSpace(QQ, 2)
            sage: ~M([4,2,2,2])
            [ 1/2 -1/2]
            [-1/2    1]
        """
        cdef Matrix_gap M
        if self._base_ring.is_field():
            M = self._new(self._nrows, self._ncols)
            M._libgap = self._libgap.Inverse()
            return M
        else:
            return Matrix_dense.__invert__(self)


    cpdef _add_(left, right):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, 3, implementation='gap')
            sage: M([1,2,3,4,3,2]) + M([1,1,1,1,1,1]) == M([2,3,4,5,4,3])
            True
        """
        cdef Matrix_gap cleft = <Matrix_gap> left
        cdef Matrix_gap ans = cleft._new(cleft._nrows, cleft._ncols)
        ans._libgap = left._libgap + (<Matrix_gap> right)._libgap
        return ans

    cpdef _sub_(left, right):
        r"""
        TESTS::

            sage: M = MatrixSpace(ZZ, 2, 3, implementation='gap')
            sage: M([1,2,3,4,3,2]) - M([1,1,1,1,1,1]) == M([0,1,2,3,2,1])
            True
        """
        cdef Matrix_gap cleft = <Matrix_gap> left
        cdef Matrix_gap ans = cleft._new(cleft._nrows, cleft._ncols)
        ans._libgap = left._libgap - (<Matrix_gap> right)._libgap
        return ans

    cdef Matrix _matrix_times_matrix_(left, Matrix right):
        r"""
        TESTS::

            sage: M = MatrixSpace(QQ, 2, implementation='gap')
            sage: m1 = M([1,2,-4,3])
            sage: m2 = M([-1,1,1,-1])
            sage: m1 * m2
            [ 1 -1]
            [ 7 -7]
        """
        if left._ncols != right._nrows:
            raise IndexError("Number of columns of self must equal number of rows of right.")
        cdef Matrix_gap M = left._new(left._nrows, right._ncols)
        M._libgap = <Matrix_gap> ((<Matrix_gap> left)._libgap * (<Matrix_gap> right)._libgap)
        return M

    def determinant(self):
        r"""
        Return the determinant of this matrix.

        EXAMPLES::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: M([2, 1, 1, 1]).determinant()
            1
            sage: M([2, 1, 3, 3]).determinant()
            3

        TESTS::

            sage: M = MatrixSpace(ZZ, 1, implementation='gap')
            sage: parent(M(1).determinant())
            Integer Ring

            sage: M = MatrixSpace(QQ, 1, implementation='gap')
            sage: parent(M(1).determinant())
            Rational Field

            sage: M = MatrixSpace(UniversalCyclotomicField(), 1, implementation='gap')
            sage: parent(M(1).determinant())
            Universal Cyclotomic Field
        """
        return self._base_ring(self._libgap.Determinant())

    def trace(self):
        r"""
        Return the trace of this matrix.

        EXAMPLES::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: M([2, 1, 1, 1]).trace()
            3
            sage: M([2, 1, 3, 3]).trace()
            5

        TESTS::

            sage: M = MatrixSpace(ZZ, 1, implementation='gap')
            sage: parent(M(1).trace())
            Integer Ring

            sage: M = MatrixSpace(QQ, 1, implementation='gap')
            sage: parent(M(1).trace())
            Rational Field

            sage: M = MatrixSpace(UniversalCyclotomicField(), 1, implementation='gap')
            sage: parent(M(1).trace())
            Universal Cyclotomic Field
        """
        return self._base_ring(self._libgap.Trace())

    def rank(self):
        r"""
        Return the rank of this matrix.

        EXAMPLES::

            sage: M = MatrixSpace(ZZ, 2, implementation='gap')
            sage: M([2, 1, 1, 1]).rank()
            2
            sage: M([2, 1, 4, 2]).rank()
            1
        """
        return int(self._libgap.Rank())