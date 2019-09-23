#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''The setup script.'''

from setuptools import setup, find_packages

with open('README.rst') as readme_file:
    readme = readme_file.read()

with open('HISTORY.rst') as history_file:
    history = history_file.read()

requirements = ['Click>=7.0', 'rply', 'funcparserlib', 'watchdog', 'anytree']

setup_requirements = ['pytest-runner']

test_requirements = ['pytest>=3']

setup(
    author='Steve Casey',
    author_email='stevecasey21@gmail.com',
    python_requires='>=3.7',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Natural Language :: English',
        'Programming Language :: Python :: 3.7',
    ],
    description='A lisp dialect that compiles to sqf.',
    entry_points={'console_scripts': ['sqisp=sqisp.cli:main']},
    install_requires=requirements,
    license='MIT license',
    long_description_content_type='text/x-rst',
    long_description=readme,
    include_package_data=True,
    keywords='sqisp',
    name='sqisp',
    packages=find_packages(include=['sqisp', 'sqisp.*']),
    setup_requires=setup_requirements,
    test_suite='tests',
    tests_require=test_requirements,
    url='https://github.com/sjcasey21/sqisp',
    version='0.6.2',
    zip_safe=False,
)
