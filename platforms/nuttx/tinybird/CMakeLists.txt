# ##############################################################################
# platforms/nuttx/tinybird/CMakeLists.txt
#
# Licensed to the Apache Software Foundation (ASF) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  The ASF licenses this
# file to you under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.
#
# ##############################################################################

if(CONFIG_INTERPRETERS_TINYBIRD)
  nuttx_add_application(
    NAME tinybird
    PRIORITY ${CONFIG_INTERPRETERS_TINYBIRD_PRIORITY}
    STACKSIZE ${CONFIG_INTERPRETERS_TINYBIRD_STACKSIZE}
    MODULE ${CONFIG_INTERPRETERS_TINYBIRD}
    SRCS tinybird_main.c
    INCLUDE_DIRECTORIES
      ${NUTTX_APPS_DIR}/interpreters/wamr/wamr/core/iwasm/include
      ${NUTTX_APPS_DIR}/interpreters/wamr/wamr/core/shared/platform/include
  )
endif()
