from setuptools import setup


setup(
    name='sonic-platform',
    version='1.0',
    description='SONiC platform API implementation on Wistron Platforms',
    license='Apache 2.0',
    author='SONiC Team',
    author_email='linuxnetdev@microsoft.com',
    url='https://github.com/Azure/sonic-buildimage',
    maintainer='ChihPei Chang',
    maintainer_email='ChihPei_Chang@wistron.com',
    packages=[
        'sonic_platform',
    ],
   package_dir={'sonic_platform': 'sonic_platform'},
   classifiers=[
        'Development Status :: 3 - Alpha',
        'Environment :: Plugins',
        'Intended Audience :: Developers',
        'Intended Audience :: Information Technology',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: Apache Software License',
        'Natural Language :: English',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python :: 2.7',
        'Topic :: Utilities',
    ],
    keywords='sonic SONiC platform PLATFORM',
)
