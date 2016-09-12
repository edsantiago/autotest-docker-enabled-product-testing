=====================================================
Autotest-Docker Enabled Product Testing (A.D.E.P.T.)
=====================================================

ADEPT includes a python program, a collection of ansible playbooks, and
related configurations.  Together, they help orchestrate a complete
run of Docker Autotest over one or more local or cloud-based systems.

.. The quickstart section begins next

Prerequisites
==============

*  Red Hat based host (RHEL_, Atomic_, CentOS_, Fedora_, etc), subscribed and fully updated.
*  Ansible_ 1.9 or later
*  Git 1.4 or later
*  Python 2.7
*  PyYAML 3.10
*  python-sphinx 1.2.3 (Optional, for building documentation)
*  python-sphinxcontrib-httpdomain 1.5.0 (Optional, same as python-sphinx)
*  python-docutils 0.11 (Optional, same as python-sphinx)
*  python-unittest2 1.1.0 (Optional, for running unittests)
*  pylint 1.3.1 (Optional, same as python-unittest2)
*  python2-mock 1.3.0 (Optional, same as python-unittest2)
*  FIXME: what else?

.. _Ansible: http://docs.ansible.com/index.html
.. _github: https://github.com
.. _RHEL: http://www.redhat.com/rhel
.. _Atomic: http://www.redhat.com/en/resources/red-hat-enterprise-linux-atomic-host
.. _CentOS: http://www.centos.org
.. _Fedora: http://www.fedoraproject.org

Quickstart
===========

::

    # Create a place for runtime details and results to be stored
    $ mkdir /tmp/workspace

    # Run the ADEPT-three-step (keyboard + finger-dance)
    $ ./adept.py setup /tmp/workspace executir.xn
    $ ./adept.py run /tmp/workspace executir.xn
    $ ./adept.py cleanup /tmp/workspace executir.xn

.. The current documentation section begins next

Latest Documentation
======================

For the latest, most up to date documentation please visit
http://autotest-docker-enabled-product-testing.readthedocs.io

The latest `Docker Autotest`_ documentation is located at:
http://docker-autotest.readthedocs.io
