
from numpy import pi
from collections import namedtuple

from utils import estimate_n0

RHO_WATER = 1e3 # kg/m^3

case = namedtuple("case", ['t_end', 'plot_dt', # seconds
                           'n_0', # number density m^-3
                           'R_0', # base drop radius meters
                           'X_0', # base drop volume m^3
                           'M_0', # base drop mass kg
                           'm_tot_ana' # initial population water mass g m^-3
                          ])

def get_case(name):
    """ Default settings for initial exponential drop distributions """

    if name == "shima_golo":
        t_end, plot_dt = 3601, 1200
        n_0 = 2.**23.
        R_0 = 30.531e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 1.0

    elif name == "shima_hydro1":
        t_end, plot_dt = 1801, 600
        n_0 = 2.**23.
        R_0 = 30.531e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 1.0

    elif name == "shima_hydro2":
        t_end, plot_dt = 3601, 1200
        n_0 = 27.*2.**23.
        R_0 = 30.531e-6/3.
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 1.0

    elif name == "simmel_golo1":
        t_end, plot_dt = 40*60 + 1, 10*60
        n_0 = 3e8
        R_0 = 9.3e-6
        # X_0 = 3.3e-12
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 1.0

    elif name == "simmel_golo3":
        t_end, plot_dt = 15*60 + 1, 5*60
        n_0 = 3e8
        R_0 = 13.4e-6
        # X_0 = 3.3e-12
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 3.0

    elif name == "simmel_long1":
        ## Simmel et al (2002) - Figure 6
        t_end, plot_dt = 40*60 + 1, 10*60
        n_0 = 3e8
        R_0 = 9.3e-6
        # X_0 = 3.3e-12
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 1.0

    elif name == "simmel_long2":
        ## Simmel et al (2002) - Figure 7
        t_end, plot_dt = 15*60 + 1, 5*60
        n_0 = 1.84e8
        R_0 = 13.0e-6
        # X_0 = 3.3e-12
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        m_tot_ana = 2.0

    elif name == "bott_golo":
        ## Bott (1998) - Figure 2
        t_end, plot_dt = 60*60+1, 15*60
        m_tot_ana = 1.0
        R_0 = 10.e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        n_0 = estimate_n0(R_0, m_tot_ana)

    elif name == "bott_hydro1":
        ## Bott (1998) - Figure 3
        t_end, plot_dt = 60*60+1, 15*60
        m_tot_ana = 1.0
        R_0 = 10.e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        n_0 = estimate_n0(R_0, m_tot_ana)

    elif name == "bott_hydro2":
        ## Bott (1998) - Figure 5
        t_end, plot_dt = 20*60+1, 5*60
        m_tot_ana = 2.0
        R_0 = 10.e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        n_0 = estimate_n0(R_0, m_tot_ana)

    elif name == "bott_hydro2.5":
        ## Bott (1998) - Figure 6 - Fig 5 w/ L = 0.5
        t_end, plot_dt = 60*60+1, 20*60
        m_tot_ana = 0.5
        R_0 = 10.e-6
        X_0 = (4.*pi/3.)*(R_0**3)
        M_0 = X_0*RHO_WATER
        n_0 = estimate_n0(R_0, m_tot_ana)

    else:
        raise ValueError("didn't understand case '%s'" % name)

    return case(t_end, plot_dt, n_0, R_0, X_0, M_0, m_tot_ana)
