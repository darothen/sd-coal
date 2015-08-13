#cython: cdivision=True
#cython: nonecheck=False
#cython: boundscheck=False
#cython: wraparound=False
#cython: profile=False

STUFF = "Hi"

cimport cython

import numpy as np
cimport numpy as cnp

from libc.stdlib cimport RAND_MAX

cdef extern from "math.h" nogil:
    double floor(double x)
    double sqrt(double x)
    double fabs(double x)

cdef extern from "stdlib.h" nogil:
    double rand()

## Inline alias functions
cdef inline int ifloor(double x): return int(floor(x))
cdef inline double dmax(double a, double b): return a if a >= b else b
cdef inline double dmin(double a, double b): return a if a <= b else b
cdef inline int imax(int a, int b): return a if a >= b else b

DEF KERNEL_ID = 1 # 1 = Golovin, 
                  # 2 = Hydro w/ E_coll=1
                  # 3 = Hydro w/ Long collection
DEF VERBOSITY = 1
DEF RHO_WATER = 1e3
DEF RHO_AIR = 1.0
DEF THIRD = 1./3.
DEF PI = 3.1415926535897932384626433832
DEF MULTI_THRESH = 1e4
cdef double RAND_FACT = float(RAND_MAX)

cdef int superdroplet_count

cdef class Superdroplet:

    cdef readonly int multi
    cdef readonly double rcubed, solute, density
    cdef readonly int id

    def __init__(self, int multi, double rcubed, double solute):
        global superdroplet_count
        superdroplet_count += 1

        self.multi  = multi
        self.rcubed = rcubed
        self.solute = solute
        self.density = RHO_WATER
        self.id = superdroplet_count

    property terminal_v:
        def __get__(self):      
            return self._terminal_v()
    cdef double _terminal_v(self) nogil:
        cdef double diameter, g, C_D, t_v
        diameter = 2*self.rcubed**(1./3.)
        g   = 9.8 # gravitational acceleration, m/s
        C_D = 0.6 # drag coefficient, unitless
        tv  = (4./3.)*(g*diameter/C_D)*(self.density/RHO_AIR)
        tv  = sqrt(tv)
        return tv

    property volume:
        def __get__(self):
            return self._volume()
    cdef double _volume(self) nogil:
        return self.rcubed*4.*PI/3.

    property mass:
        def __get__(self):
            return self._mass()
    cdef double _mass(self) nogil:
        return self.density*self._volume()

    def attributes(self):
        return { 
            'multi': self.multi, 
            'rcubed': self.rcubed,
            'solute': self.solute,
        }

    cpdef copy(self):
        return Superdroplet(self.multi, self.rcubed, self.solute)

    def __repr__(self):
        return "%d" % self.id

ctypedef Superdroplet Superdroplet_t

cdef int sd_compare(Superdroplet_t a, Superdroplet_t b):
    return a.multi - b.multi

cpdef double kernel(Superdroplet_t sd_j, Superdroplet_t sd_k):
    cdef double b = 1.5e3 # constant for Golovin
    cdef double E_coll, E_coal = 1.0
    cdef double p, r_j, r_k, 
    cdef double tv_j, tv_k
    cdef double r_small, r_large
    cdef double tv_diff, r_sum

    if KERNEL_ID == 1:
        return b*(sd_j.rcubed + sd_k.rcubed)*4.*PI/3.

    p = 1./3.
    r_j = sd_j.rcubed**p
    r_k = sd_k.rcubed**p

    tv_j = sd_j._terminal_v()
    tv_k = sd_k._terminal_v()

    tv_diff = tv_j - tv_k
    r_sum = r_j + r_k

    if KERNEL_ID == 2:
        E_coll = 1.0
        E_coal = 1.0

    elif KERNEL_ID == 3:
        ## Long (1974) collision kernel
        r_small = dmin(r_j, r_k)
        r_large = dmax(r_j, r_k)

        if r_large >= 50e-6: # microns
            E_coll = 1.0
        else:
            E_coll = dmax(4.5e4 * (r_large*r_large*1e4) * \
                          (1. - 3e-4/(r_small*1e2)),
                          1e-3 )
        E_coal = 1.0

    else: 
        E_coll = 1.0
        E_coal = 1.0

    # Limit collection efficiency to 0 <= E_coll <= 1.0
    E_coll = dmin(E_coll, 1.0)
    E_coll = dmax(0.0, E_coll)

    return (E_coll*E_coal)*PI*(r_sum*r_sum)*fabs(tv_diff)

cdef list multi_coalesce(Superdroplet_t sd_j, 
                         Superdroplet_t sd_k, 
                         double gamma):
    """
    Coalesce two superdroplets with one another.
    """

    cdef Superdroplet_t sd_temp, sd_recycle
    cdef double gamma_tilde
    cdef int multi_j_p, multi_k_p, excess
    cdef double solute_j_p, solute_k_p, rcubed_j_p, rcubed_k_p

    if sd_j.multi < sd_k.multi:
        sd_temp = sd_j.copy()
        sd_j = sd_k.copy()
        sd_k = sd_temp

    gamma_tilde = dmin(gamma, ifloor(sd_j.multi/sd_k.multi))
    excess = sd_j.multi - ifloor(gamma_tilde*sd_k.multi)

    if excess > 0:

        multi_j_p = excess # = sd_j.multi - ifloor(gamma_tilde*sd_k.multi)
        multi_k_p = sd_k.multi

        rcubed_j_p = sd_j.rcubed
        rcubed_k_p = gamma_tilde*sd_j.rcubed + sd_k.rcubed

        solute_j_p = sd_j.solute
        solute_k_p = gamma_tilde*sd_j.solute + sd_k.solute

        sd_temp = Superdroplet(multi_j_p, rcubed_j_p, solute_j_p)
        sd_recycle = Superdroplet(multi_k_p, rcubed_k_p, solute_k_p)

    else: # implies excess == 0

        # print "NO EXCESS", sd_j.multi, sd_k.multi

        multi_j_p = ifloor(sd_k.multi / 2)
        multi_k_p = sd_k.multi - multi_j_p

        # if multi_j_p == 0:
        #     print "WHAT J"
        # if multi_j_p == 0:
        #     print "WHAT K"

        sd_temp = Superdroplet(multi_k_p, 
                               gamma_tilde*sd_j.rcubed + sd_k.rcubed,
                               gamma_tilde*sd_j.solute + sd_k.solute)
        sd_recycle = Superdroplet(multi_j_p, 
                                  gamma_tilde*sd_j.rcubed + sd_k.rcubed,
                                  gamma_tilde*sd_j.solute + sd_k.solute)

    return [ sd_temp, sd_recycle ]

def recycle(list sds):
    """ For a list of superdroplets, identify which ones have 0 
    multiplicities; for each *i* of these, pick the superdroplet 
    with the *i*th-most multiplicity, split it in half, and copy 
    the properties to the remaining superdroplet. """

    print "RECYCLE", 

    sds.sort(cmp=sd_compare)

    cdef:
        int i
        Superdroplet_t sd, sd_donor

    for i, sd in enumerate(sds):
        # Short circuits:
        # 1) Did we already encounter non-zero superdroplets?
        if sd.multi > 0: break

        sd_donor = sds[-i]
        # 2) Does the donor superdroplet have data to spare?
        if sd_donor.multi <= 0: break

        sd.multi = ifloor(sd_donor.multi/2)
        sd_donor.multi -= ifloor(sd_donor.multi/2)

        sd.rcubed = sd_donor.rcubed
        sd.solute = sd_donor.solute
    print " %d superdroplets" % i

    return sds

def step(list sd_list, 
         double t_c, double delta_V):

    print "PREP STEPS"
    # 1) Make the random permutation of the super-droplet list
    print "   SHUFFLE LIST"
    np.random.shuffle(sd_list)

    # 2) Make the candidate pairs
    print "   GEN PAIRS"
    cdef long n_part = <long> len(sd_list)

    # 3) Generate the uniform random numbers
    print "PROBABILITY LOOP"
    cdef double scaling = (n_part*(n_part - 1)/2.)/ifloor(n_part/2)    

    print "PROB / COLLISION LOOP"
    cdef bint collisions = False
    cdef int counter = 0
    cdef:
        unsigned int i
        Superdroplet_t sd_j, sd_k
        double gamma
        # Superdroplet_t[:] new_pair
        list new_pair
        double phi, p_alpha
        int xi_j, xi_k, max_xi
        double K_ij

        double gamma_tilde
        int multi_j_p, multi_k_p, excess
        double rcubed_j_p, rcubed_k_p, solute_j_p, solute_k_p

        cdef double b = 1.5e3, rj3, rk3

        cdef int big_probs = 0
        cdef double max_prob = 0.0, min_prob = 1.0

    for i in xrange(n_part/2):
        sd_j = sd_list[i]
        sd_k = sd_list[i + n_part/2]

        phi = rand() / RAND_FACT
        xi_j = sd_j.multi
        xi_k = sd_k.multi

        K_ij = kernel(sd_j, sd_k)
        max_xi = imax(xi_j, xi_k)
        prob = scaling*max_xi*(t_c/delta_V)*K_ij

        if prob > max_prob: max_prob = prob
        if prob < min_prob: min_prob = prob
        if prob > 1: big_probs += 1

        # Limit the probability when comparing to the uni draw
        if (prob - floor(prob)) < phi: # no collision!
            sd_list[i] = sd_j
            sd_list[i + n_part/2] = sd_k

        else:
            gamma = floor(prob) + 1
            new_pair = multi_coalesce(sd_j, sd_k, gamma)
            sd_j, sd_k = new_pair

            sd_list[i] = sd_j
            sd_list[i + n_part/2] = sd_k

            if not collisions:
                collisions = True
            counter += 1

    print "%5d collisions simulated" % counter
    print " Max/min probabilities (count): ", min_prob, max_prob, big_probs

    return sd_list
