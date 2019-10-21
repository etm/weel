# This file is part of WEEL.
#
# WEEL is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# WEEL is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# WEEL (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require ::File.dirname(__FILE__) + '/../lib/weel'
require ::File.dirname(__FILE__) + '/SimpleHandlerWrapper'

class SimpleWorkflow < WEEL
  handlerwrapper SimpleHandlerWrapper

  endpoint :ep1 => "orf.at"
  data :a => 17

  control flow do
    call :a1, :ep1, parameters: { :a => data.a, :b => 2 } do
      data.a += 3
    end
  end
end
