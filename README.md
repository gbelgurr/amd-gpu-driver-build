Marek's approach to building AMD GPU drivers for driver development
===================================================================

You are going to need autoconf, automake, libtool, cmake, ninja, gcc, g++, and many lib development packages required by all the components.

Copy the files from this repository into the directory where you are going to clone all git repositories, so that the files are above the repository directories.


Use git to clone these:
- kernel: the internal AMD drm-next repository is recommended for AMD employees
- libdrm: https://cgit.freedesktop.org/mesa/drm/ (find the link)
- llvm: https://git.llvm.org/git/llvm.git (clone directly)
- mesa: https://cgit.freedesktop.org/mesa/mesa/ (find the link)
- waffle: https://github.com/waffle-gl/waffle (find the link)
- piglit: https://cgit.freedesktop.org/piglit/ (find the link)

You can skip kernel and llvm if you don't intend to work on those. You are going to need llvm development packages if you are not going to build llvm manually.

Configure and build everything in the listed order, because there are dependencies.

kernel, libdrm, and llvm don't depend on anything.
mesa depends on libdrm and llvm.
waffle depends on mesa.
piglit depends on mesa and waffle.


Building
--------

Most components may require installation of additional development library packages. Follow error messages to resolve them.

Go to the kernel directory and type:
```
make menuconfig # (if needed to change something)
../build_kernel.sh
```
It will build and install the kernel.

Go to the libdrm directory and type:
```
../conf_drm.sh
make -j16
sudo make install
```

Go to the llvm directory and type:
```
../conf_llvm.sh
cd build
ninja
sudo ninja install
```
`conf_llvm.sh` might fail for the build32 part of the script. Ignore that for now.

LLVM is installed outside of `/usr/lib`, so you need to copy the contents of the `etc` directory from this repository into `/etc`. Then, type this to notify ld about it:
```
sudo ldconfig
```
Now ld will be able to find LLVM.

Before or after installing Mesa on Ubuntu 16.04, the following hack has to be done: Remove all `libGL.*` and `libEGL.*` files that are not directly in `/usr/lib/x86_64-linux-gnu`, but are in subdirectories of that directory. You have to do it every time Ubuntu updates its Mesa packages.

Go to the mesa directory and type:
```
../conf_mesa.sh
make -j16
sudo make install
```
Mesa contains libGL, libEGL, libgbm, and libglapi in addition to drivers.

Go to the waffle directory and type:
```
../conf_waffle.sh
ninja
sudo ninja install
```

Go to the piglit directory and type:
```
../conf_piglit.sh
ninja
```
There is no installation step for piglit.


First test
----------

To verify that everything is installed properly, run `driver-load-sanity-test` and `driver-render-sanity-test` from this repository. They have to pass for X to be able to even start. Those two are also the first tests to run when debugging X startup issues, because they use the same APIs as X (that is GBM + EGL).

Now reboot your machine and everything should work.

X crashes can also be debugged via gdb over ssh: `sudo gdb /usr/lib/xorg/Xorg`


Building 32-bit drivers
-----------------------

This step is unnecessary if you don't expect to test certain Steam games. It's the same as above except that you add `-32` like this:
```
../conf_drm.sh -32
../conf_mesa.sh -32
```
I recommend that you clone separate directories for those, called `drm32` and `mesa32`. The symlink script below requires that directory layout.

LLVM is already configured for the 32-bit build in its build32 directory. (if it didn't fail when you configured it above)


Mesa development without `make install`
---------------------------------------

You have to do `make install` for the first time, so that waffle and piglit can find the latest Mesa, but you don't have to do that for any subsequent rebuilds of Mesa if you want to use the following method.

Run `make-mesa-symlinks.sh`. It will create symlinks pointing from the Mesa installation locations in `/usr/lib/....` into your `mesa` and `mesa32` directories. Now, rebuilding Mesa is all you need to make it visible to applications.

The less invasive alternative is to set these environment variables:
- `LIBGL_DRIVERS_PATH` to your `mesa/x86_64-linux-gnu/gallium` directory
- `LD_LIBRARY_PATH` to your `mesa/x86_64-linux-gnu` directory

I recommend using `LD_LIBRARY_PATH` for LLVM development without `ninja install`.


Piglit regression testing
-------------------------

Use `run-piglit.sh` from this repository. It will run piglit and create an HTML report.

To run piglit for the first time, type:
```
./run-piglit.sh
```

It will print the name of the run, for example:
```
Name: 04-11_19:35_VEGA12
```
The name of the run will also be on the first row of the HTML report table.

If you want to run piglit and compare it against a baseline, specify the baseline name on the command line. It will create an HTML report comparing your current run with the baseline:
```
./run-piglit.sh 04-11_19:35_VEGA12
```
The piglit results are stored in the piglit-results directory, while the HTML reports are stored separately in the piglit-summary directory. You can always regenerate the reports from the results, or generate comparisons between two or more sets of results.

Other examples:
- `./run-piglit.sh 04-11_19:35_VEGA12 -c`: force concurrency for all tests (recommended but most tests are already run concurrently)
- `./run-piglit.sh -- -c`: if you want to specify a parameter but not a baseline, use `--` instead
- `./run-piglit.sh 04-11_19:35_VEGA12 -c -x view`: exclude all tests containing `view` in their name
- `./run-piglit.sh 04-11_19:35_VEGA12 -c -t clear`: run only tests containing `clear` in their name
- `./run-piglit.sh 04-11_19:35_VEGA12 -c -t clear -x view`: run tests containing `clear` but not containing `view`
- `./run-piglit.sh 04-11_19:35_VEGA12 -1 -v`: disable concurrency (`-1`) and print the name of each test (`-v`)

Disabling concurrency can help if you have an unstable kernel driver.


What to do if piglit hangs the GPU
----------------------------------

Run piglit with the `-isol` parameter before the baseline name:
```
./run-piglit.sh -isol 04-11_19:35_VEGA12 -c
```
`-isol` enables process isolation for tests, meaning that tests are run as separate processes instead of combined into one process. This will make full test executable command lines visible to `ps`.

When it hangs, run `ps aux|grep piglit` over ssh to get command lines of currently running tests. After reboot, you can run each line separately to find the hanging test.