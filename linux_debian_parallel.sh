#!/bin/bash

# Exit immediately if error
set -e

###########################################################################
# References:
#  https://xyce.sandia.gov/documentation/BuildingGuide.html
#
# Purpose:
#  Compiles and installs latest release of Xyce and dependencies
#  into /opt/XyceLibs/Parallel and /opt/XyceLibs/Parallel
#  Also sets PATH and ALIAS for Xyce
#
# Usage:
#  Run with sudo:
#   sudo Install_Xyce
#
#  If you want to start the script detached from your current shell:
#   sudo Install_Xyce [--detached -d]
#  The process ID will be printed if run detached. Alternatively, To check or 
#  get the process ID of the script:  
#   ps -ef | grep Install_Xyce.sh 
#  To kill the installation procces use (where XYCE_INSTALL_PID can be 
#  found using the previous command.
#   kill -0 $XYCE_INSTALL_PID
#  WARNING: This may not kill all the proccess as the script 	spawns other
#  processes (some in parallel). You can either use `ps -ef | grep Xyce to 
#  get all process IDs (might be a lot) and kill them all or let the 
#  processes that have initiated finish executing.
#
#  Once installed:
#   To run serially:
#    Xyce -l sample.log <netlist filename>
#   To run parallely (where 4 is the number of parallel processes):
#   Xyce-parallel 4 -o results <netlist filename>
#
###########################################################################

# Check for root priviledges
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Error: Not running as root or using sudo"
    echo "Installation aborted"
    exit 0
fi

# If -d or --daemon passed as the first argument, detachs the script from the current shell:
case "$1" in
    -d|--daemon)
        $0 < /dev/null &> Xyce_install-$(date +'%Y-%m-%d-%H%M').log & disown
        export $XYCE_INSTALL_PID=$!
        echo "Xyce compilation and installation proccesses running in background with root process ID: $!"
        exit 0
        ;;
    *)
        ;;
esac

# All the compilation and installation code
function main() {
    #Dependencies
    sudo apt-get install -y gcc g++ gfortran make cmake bison flex libfl-dev libfftw3-dev libsuitesparse-dev libblas-dev liblapack-dev libtool autoconf automake git libopenmpi-dev openmpi-bin

    # Set up install directories
    INSTALLDIR=/opt

    mkdir -p $INSTALLDIR/XyceLibs/Parallel
    mkdir -p $INSTALLDIR/Xyce/Parallel

    rm -rf $INSTALLDIR/.xycetemp
    mkdir -p $INSTALLDIR/.xycetemp/Trilinos12.12
    mkdir -p $INSTALLDIR/.xycetemp/XyceBuild

    # Install Trilinos from source
    cd $INSTALLDIR/.xycetemp/Trilinos12.12
    wget https://github.com/trilinos/Trilinos/archive/trilinos-release-12-12-1.tar.gz 
    tar zxvf trilinos-release-12-12-1.tar.gz

    SRCDIR=$INSTALLDIR/.xycetemp/Trilinos12.12/Trilinos-trilinos-release-12-12-1
    ARCHDIR=$INSTALLDIR/XyceLibs/Parallel
    FLAGS="-O3 -fPIC"
    #Uses parallel processes
    cmake \
    -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER=mpicc \
    -DCMAKE_CXX_COMPILER=mpic++ \
    -DCMAKE_Fortran_COMPILER=mpif77 \
    -DCMAKE_CXX_FLAGS="$FLAGS" \
    -DCMAKE_C_FLAGS="$FLAGS" \
    -DCMAKE_Fortran_FLAGS="$FLAGS" \
    -DCMAKE_INSTALL_PREFIX=$ARCHDIR \
    -DCMAKE_MAKE_PROGRAM="make" \
    -DTrilinos_ENABLE_NOX=ON \
    -DNOX_ENABLE_LOCA=ON \
    -DTrilinos_ENABLE_EpetraExt=ON \
    -DEpetraExt_BUILD_BTF=ON \
    -DEpetraExt_BUILD_EXPERIMENTAL=ON \
    -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
    -DTrilinos_ENABLE_TrilinosCouplings=ON \
    -DTrilinos_ENABLE_Ifpack=ON \
    -DTrilinos_ENABLE_Isorropia=ON \
    -DTrilinos_ENABLE_AztecOO=ON \
    -DTrilinos_ENABLE_Belos=ON \
    -DTrilinos_ENABLE_Teuchos=ON \
    -DTrilinos_ENABLE_COMPLEX_DOUBLE=ON \
    -DTrilinos_ENABLE_Amesos=ON \
    -DAmesos_ENABLE_KLU=ON \
    -DTrilinos_ENABLE_Amesos2=ON \
    -DAmesos2_ENABLE_KLU2=ON \
    -DAmesos2_ENABLE_Basker=ON \
    -DTrilinos_ENABLE_Sacado=ON \
    -DTrilinos_ENABLE_Stokhos=ON \
    -DTrilinos_ENABLE_Kokkos=ON \
    -DTrilinos_ENABLE_Zoltan=ON \
    -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
    -DTrilinos_ENABLE_CXX11=ON \
    -DTPL_ENABLE_AMD=ON \
    -DAMD_LIBRARY_DIRS="/usr/lib" \
    -DTPL_AMD_INCLUDE_DIRS="/usr/include/suitesparse" \
    -DTPL_ENABLE_BLAS=ON \
    -DTPL_ENABLE_LAPACK=ON \
    -DTPL_ENABLE_MPI=ON \
    $SRCDIR

    make

    sudo make install

    ##############################################################################

    cd $INSTALLDIR/.xycetemp

    mkdir -p ~/.ssh/
    ssh-keyscan github.com >> ~/.ssh/known_hosts
    git clone https://github.com/Xyce/Xyce.git

    #Build Xyce
    cd Xyce
    ./bootstrap
    cd $INSTALLDIR/.xycetemp/XyceBuild
    # --disable-option-checking  ignore unrecognized --enable/--with options
    # --disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
    # --enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
    # --enable-silent-rules   less verbose build output (undo: "make V=1")
    # --disable-silent-rules  verbose build output (undo: "make V=0")
    # --disable-xyce-binary   Disables building of the xyce executable. (Default
    #                         is to build the binary)
    # --enable-xyce-shareable Enables building of the shareable xyce executable.
    #                         (Default is to build the non-shareable)
    # --enable-user-plugin    enables building of the demo verilog plug-in as part
    #                         of "make all" when doing shared executable build.
    #                         You must have ADMS installed for this to work.
    #                         (Default is only to build the plugin with "make
    #                         plugin")
    # --enable-mpi            enable parallel build with MPI.
    # --enable-verbose_time   enable verbosity in time integrator.
    # --enable-verbose_nonlinear
    #                         enable verbosity in nonlinear solver.
    # --enable-verbose_nox    enable verbosity in NOX nonlinear solver library.
    # --enable-verbose_linear enable verbosity in linear solver.
    # --enable-bsim3_const    enable using constants from BSIM3 instead of more
    #                         precise constants consistent with other devices.
    # --enable-radmodels      enable Radiation Model Library.
    # --enable-admsmodels     enable ADMS Model Library.
    # --enable-neuronmodels   enable NEURON Model Library.
    # --enable-nonfree        enable Non-Free Models Library.
    # --enable-modspec        enable ModSpec Interface.
    # --enable-dakota         enable Dakota direct linkage support.
    # --enable-charon         enable Charon device support.
    # --enable-isorropia      enable isorropia partitioning option.
    # --enable-zoltan         enable zoltan partitioning option.
    # --enable-superlu        enable SuperLU direct solver.
    # --enable-pardiso_mkl    enable Pardiso direct solver (through MKL).
    # --enable-shylu          enable ShyLU hybrid solver support.
    # --enable-amesos2        enable Amesos2 direct solver support.
    # --enable-rol            enable ROL optimization library support.
    # --enable-stokhos        enable Stokhos UQ library support.
    # --enable-amd            enable AMD reordering.
    # --enable-superludist    enable SuperLU_Dist linear solver.
    # --enable-debug_device   enable device package debugging output.
    # --enable-debug_io       enable I/O package debugging.
    # --enable-debug_expression
    #                         enable Expression package debugging output.
    # --enable-debug_time     enable time integrator package debugging output.
    # --enable-debug_analysis enable analysis package debugging output.
    # --enable-debug_hb       enable Harmonic balance analysis package debugging
    #                         output.
    # --enable-debug_es       enable embedded sampling analysis package debugging
    #                         output.
    # --enable-debug_sampling enable traditional sampling analysis package
    #                         debugging output.
    # --enable-debug_mor      enable Model order reduction debugging output.
    # --enable-debug_parallel enable parallel distribution package debugging
    #                         output.
    # --enable-debug_distribution
    #                         enable distribution package debugging output.
    # --enable-debug_topology enable topology package debugging output.
    # --enable-debug_linear   enable linear solver package debugging output.
    # --enable-debug_nonlinear
    #                         enable nonlinear solver package debugging output.
    # --enable-debug_circuit  enable circuit package debugging output.
    # --enable-debug_directsolve
    #                         enable direct solver package debugging output.
    # --enable-debug_restart  enable restart debugging output.
    # --enable-fortran_blas   enable test for fortran blas using fortran compiler
    #                         --- disable this if you are using C blas.
    # --enable-reaction_parser
    #                         enable reaction parser.
    # --enable-fft            enable support for FFT libraries.
    # --enable-intel_fft      enable support for Intel MKL FFT library.
    # --enable-fftw           enable support for FFTW library.
    # --enable-athena         enable building the ATHENA device.
    # --enable-adms_sensitivities
    #                         enable analytic sensitivities in ADMS-generated
    #                         device models.
    # --enable-curl           enable support for curl for metrics reporting.
    # --enable-dependency-tracking
    #                         do not reject slow dependency extractors
    # --disable-dependency-tracking
    #                         speeds up one-time build
    # --enable-shared[=PKGS]  build shared libraries [default=no]
    # --enable-static[=PKGS]  build static libraries [default=yes]
    # --enable-fast-install[=PKGS]
    #                         optimize for fast installation [default=yes]
    # --disable-libtool-lock  avoid locking (might break parallel builds)

    # Optional Packages:
    # --with-PACKAGE[=ARG]    use PACKAGE [ARG=yes]
    # --without-PACKAGE       do not use PACKAGE (same as --with-PACKAGE=no)
    # --with-pic[=PKGS]       try to use only PIC/non-PIC objects [default=use
    #                         both]
    # --with-aix-soname=aix|svr4|both
    #                         shared library versioning (aka "SONAME") variant to
    #                         provide on AIX, [default=aix].
    # --with-gnu-ld           assume the C compiler uses GNU ld [default=no]
    # --with-sysroot[=DIR]    Search for dependent libraries within DIR (or the
    #                         compiler's sysroot if not specified).

    "$INSTALLDIR/.xycetemp/Xyce/configure" \
    CXXFLAGS="-O3" \
    ARCHDIR="$INSTALLDIR/XyceLibs/Parallel" \
    CPPFLAGS="-I/usr/include/suitesparse" \
    --enable-mpi \
    CXX=mpicxx \
    CC=mpicc \
    F77=mpif77 \
    --enable-stokhos \
    --enable-amesos2 \
    --prefix="$INSTALLDIR/Xyce/Parallel"

    make
    sudo make install


    #Clean temporary source and build files
    rm -rf $INSTALLDIR/.xycetemp

    #Adds Xyce to PATH and adds alias for Xyce in parallel mode
    #Example Usage:
    # Xyce -l sample.log <netlist filename>
    # Xyce-parallel 4 -o results <netlist filename>
    if [ -d "/opt/Xyce/Parallel/bin" ] && [ ":$PATH:" != *":/opt/Xyce/Parallel/bin:"* ]; then
        sudo echo 'export PATH="$PATH:/opt/Xyce/Parallel/bin"' > /etc/profile.d/Xyce.sh
        sudo echo 'alias Xyce-parallel="mpirun -np $1 Xyce"' >> /etc/profile.d/Xyce.sh
    fi
}

if ! main; then
    echo "Xyce compilation and installation aborted due to errors"
fi