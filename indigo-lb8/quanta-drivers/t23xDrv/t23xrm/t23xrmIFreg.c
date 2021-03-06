
/*
 * t23xrmIFreg.c
 *
 * Extensible resource manager interface registration/deregistration
 * functionality for t23x
 *
 * Copyright (c) 2007, Freescale Semiconductor, Inc.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in
 *   the documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of Freescale Semiconductor nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *
 */



/** @file   
 * Handles registration of extensible "interfaces" with the resource
 * manager, so that the RM can organize requests from differing sources
 */

#include "../common/xwcRMinterface.h"
#include "t23xrmInternal.h"


extern RMinterfaceCtx ifCtx[MAX_INTERFACES];

/**
 * Register an interface with the resource manager.
 *
 * @param intname - name of this interface, the RM will use
 *           this as an identifier tag
 *
 * @param regdesc - points to a reference used to identify
 *           the context for this interface
 *
 * @return RMstatus
 */

RMstatus xwcRMregisterInterface(uint8_t         *intname,
                                RMinterfaceCtx **regdesc)
{
    int32_t i = 0;

#ifdef RM_DBG_APITRACE
    printk("xwcRMregisterInterface(intname=%s,regdesc=0x%08x)\n",
           intname,
           (uint32_t)regdesc);
#endif

    if (intname == NULL)
        return RM_BAD_REGISTRATION_RQ;

    while (i < MAX_INTERFACES)
        if (ifCtx[i].inUse)
            i++;
        else
        {
            ifCtx[i].inUse = INTFC_IN_USE;
            strncpy(ifCtx[i].ifName, intname, INTFC_NAME_LEN);
            *regdesc = &ifCtx[i];
            return(RM_OK);
        }

    return RM_MAX_INTFC_REGISTERED;
}



/**
 * Deregister an interface from the resource manager
 * @param *regdesc
 * @return
 */

RMstatus xwcRMderegisterInterface(RMinterfaceCtx *regdesc)
{
    int32_t i = 0;

#ifdef RM_DBG_APITRACE
    printk("xwcRMderegisterInterface(regdesc=0x%08x)\n",
           (uint32_t)regdesc);
#endif

    /* May have to check the status of pending requests first */

    /* Is pointer mis-specified? */
    if (regdesc == NULL)
        return RM_BAD_DEREGISTRATION_RQ;

    /* Deregistration is built into this loop to insure that    */
    /* the pointer specified is a valid reg context,            */
    /* no other reason                                          */
    while (i < MAX_INTERFACES)
    {
        if (regdesc == &ifCtx[i])
        {
            regdesc->inUse = INTFC_AVAILABLE;
            memset(regdesc->ifName, 0, INTFC_NAME_LEN);
            return RM_OK;
        }
        i++;
    }

    return RM_BAD_DEREGISTRATION_RQ;
}


