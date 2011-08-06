/*
 * Copyright 2010 Big Switch Networks
 *
 * This code is released under the OpenFlow license.
 *
 * We are making this software available for public use and benefit
 * with the expectation that others will use, modify and enhance the 
 * Software and contribute those enhancements back to the community. 
 * However, since we would like to make the Software available for 
 * broadest use, with as few restrictions as possible permission is 
 * hereby granted, free of charge, to any person obtaining a copy of 
 * this Software to deal in the Software under the copyrights without 
 * restriction, including without limitation the rights to use, copy, 
 * modify, merge, publish, distribute, sublicense, and/or sell copies 
 * of the Software, and to permit persons to whom the Software is 
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be 
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED -Y´AS IS¡, WITHOUT WARRANTY OF ANY KIND, 
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in 
 * advertising or publicity pertaining to the Software or any 
 * derivatives without specific, written prior permission.
 *
 */

/*
 * OpenFlow object to/from JSON object parsing
 *
 * These routines encode/decode OpenFlow flow C structures to/from
 * JSON representations.
 *
 * Limitations:  Vendor actions are limited to 64 bytes of data
 * beyond the vendor header.  They are passed as raw data (encoded as
 * a hex string) and hence any data contained therein is in the host
 * order of the sending machine.
 *
 */

#if !defined(_OF_JSON_H_)
#define _OF_JSON_H_

#include <openflow/openflow.h>
#include <udatapath/switch-flow.h>
#include <json/json.h>

#endif /* _OF_JSON_H_ */

