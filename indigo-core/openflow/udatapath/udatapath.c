/* Copyright (c) 2008 The Board of Trustees of The Leland Stanford
 * Junior University
 * 
 * We are making the OpenFlow specification and associated documentation
 * (Software) available for public use and benefit with the expectation
 * that others will use, modify and enhance the Software and contribute
 * those enhancements back to the community. However, since we would
 * like to make the Software available for broadest use, with as few
 * restrictions as possible permission is hereby granted, free of
 * charge, to any person obtaining a copy of this Software to deal in
 * the Software under the copyrights without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * 
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any
 * derivatives without specific, written prior permission.
 */

#include <config.h>
#include <errno.h>
#include <getopt.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "command-line.h"
#include "daemon.h"
#include "datapath.h"
#include "fault.h"
#include "openflow/openflow.h"
#include "poll-loop.h"
#include "queue.h"
#include "util.h"
#include "rconn.h"
#include "timeval.h"
#include "vconn.h"
#include "dirs.h"
#include "vconn-ssl.h"
#include "vlog-socket.h"
#include "watchdog.h"
#include "sprof.h"

#if defined(OF_HW_PLAT)
#include <of_hw_api.h>
#include <of_indigo_version.h>
#endif

void udatapath_status(void);

#if defined(SPROF_SUPPORT)
sprof_block_t sprof_blocks[SPROF_POINTS_MAX];
char *sprof_names[SPROF_POINTS_MAX] = SPROF_NAMES_INIT;
void (*sprof_hook_f)(void) = udatapath_status;
#endif

#if defined(WATCHDOG_SUPPORT)
int watchdog_active;
int wd_fd = -1;
#endif

#define THIS_MODULE VLM_udatapath
#include "vlog.h"

/* Strings to describe the manufacturer, hardware, and software.  This data 
 * is queriable through the switch description stats message. */
#if defined(OF_HW_PLAT)
char mfr_desc[DESC_STR_LEN] = INDIGO_MFR_DESC;
char sw_desc[DESC_STR_LEN] = INDIGO_REL_NAME;
char dp_desc[DESC_STR_LEN] = "Indigo on unknown hardware";
char hw_desc[DESC_STR_LEN] = "Unknown Indigo Platform";

#else /* Not OF_HW_PLAT */
char mfr_desc[DESC_STR_LEN] = "Unknown";
char sw_desc[DESC_STR_LEN] = VERSION BUILDNR;
char dp_desc[DESC_STR_LEN] = "";
char hw_desc[DESC_STR_LEN] = "Reference Userspace Switch";
#endif /* OF_HW_PLAT */
char serial_num[SERIAL_NUM_LEN] = "None";

static int hw_desc_set = false;
static int dp_desc_set = false;

static void parse_options(int argc, char *argv[]);
static void usage(void) NO_RETURN;

static struct datapath *dp;
static uint64_t dpid = 0;
static char *port_list;
static char *local_port = "tap:";
static uint16_t num_queues = NETDEV_MAX_QUEUES;

/* Support indicating range of port numbers to add; see -m, -M */
static int max_port_set = false;
static int min_port = 1;
static int max_port;

/* Was the MAC address specified on the cmd line? */
static int got_mac = false;
static uint8_t dp_mac[ETH_ADDR_LEN];

/* Datapath management:  This means that the "local port" can be 
 * connected to a dataplane port.  This is mainly for HW platform 
 * support where a separate handler is used for multiplexing/demultiplexing
 * packets to the dataplane ports 
 */
static int dp_mgmt = false;
static int dp_mgmt_oob = false;
static int dp_mgmt_port = 1;
static int dp_mgmt_port_fixed = false;
static int dp_mgmt_vid = -1;
static int dp_mgmt_vid_fixed = false;
static int port_add_state = PORT_ADD_STATE_UP; /* Enables port */

static void add_ports(struct datapath *dp, char *port_list);
static void add_ports_range(struct datapath *dp, int min_port, int max_port);

/* Need to treat this more generically */
#if defined(UDATAPATH_AS_LIB)
#define OFP_FATAL(_er, _str, args...) do {                \
        fprintf(stderr, _str, ## args);                   \
        return -1;                                        \
    } while (0)
#else
#define OFP_FATAL(_er, _str, args...) ofp_fatal(_er, _str, ## args)
#endif

/* 0 on success */
static int
str_to_mac(const char *str, uint8_t mac[6]) 
{
    if (sscanf(str, "%"SCNx8":%"SCNx8":%"SCNx8":%"SCNx8":%"SCNx8":%"SCNx8,
               &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]) != 6) {
        return -1;
    }
    return 0;
}

#if !defined(UDATAPATH_AS_LIB)
int
main(int argc, char *argv[])
{
    return udatapath_cmd(argc, argv);
}
#endif

/* Print status to string, return bytes written */
int
udatapath_status_string(char *buf, int bytes)
{
    char * ptr;
    void *params[2];
    int out;

    ptr = buf;

    if (dp) {
        out = snprintf(ptr, bytes, "Datapath: %s\n", dp->dp_desc);
        ptr += out;
        bytes -= out;
        out = snprintf(ptr, bytes, "Poll time %d; rmt run lmt %d.\n",
                       POLL_TIME_DEFAULT, REMOTE_RUN_LIMIT);
        ptr += out;
        bytes -= out;
        out = datapath_status_string(dp, ptr, bytes);
        ptr += out;
        bytes -= out;
        params[0] = &ptr;
        params[1] = &bytes;
        dp->hw_drv->ioctl(dp->hw_drv, OF_HW_IOCTL_SHOW, params, 0);
    } else {
        out = snprintf(ptr, bytes, "No datapath found\n");
        ptr += out;
        bytes -= out;
    }

    return ptr - buf;
}

void
udatapath_status(void)
{
    if (dp) {
        printf("Datapath %p: %s\n", dp, dp->dp_desc);
        printf("Poll time %d; rmt run lmt %d.\n",
               POLL_TIME_DEFAULT, REMOTE_RUN_LIMIT);
        WATCHDOG_STATE;
        datapath_status(dp);
        dp->hw_drv->ioctl(dp->hw_drv, OF_HW_IOCTL_SHOW, NULL, 0);
    } else {
        printf("No datapath found\n");
    }
    SPROF_DUMP();
}

/*
 * Publish the global datapath pointer
 */
struct datapath *
of_datapath_get(void)
{
    return dp;
}

int
udatapath_cmd(int argc, char *argv[])
{
    int n_listeners;
    int error;
    int i;

    set_program_name(argv[0]);
    register_fault_handlers();
    time_init();
    vlog_init();
    parse_options(argc, argv);
    signal(SIGPIPE, SIG_IGN);

    if (argc - optind < 1) {
        OFP_FATAL(0, "at least one listener argument is required; "
          "use --help for usage");
    }

    error = dp_new(&dp, dpid);
    if (error) {
        OFP_FATAL(error, "Failed to create datapath.  Exiting.");
    }
#if defined(OF_HW_PLAT)
    if (got_mac) {
        memcpy(dp->dp_mgmt.mac, dp_mac, ETH_ADDR_LEN);
    } else {  /* Use OF OUI and 3 bytes of DPID */
        dp->dp_mgmt.mac[0] = 0;
        dp->dp_mgmt.mac[1] = 0x26;
        dp->dp_mgmt.mac[2] = 0xe1;
        dp->dp_mgmt.mac[3] = dp->id & 0xff;
        dp->dp_mgmt.mac[4] = (dp->id >> 8) & 0xff;
        dp->dp_mgmt.mac[5] = (dp->id >> 16) & 0xff;
    }
    dp_port_add_state_set(dp, port_add_state);

    dp->dp_mgmt.enabled = dp_mgmt;
    dp->dp_mgmt.port_fixed = dp_mgmt_port_fixed;
    dp->dp_mgmt.port = dp_mgmt_port;
    dp->dp_mgmt.vid_fixed = dp_mgmt_vid_fixed;
    dp->dp_mgmt.vid = dp_mgmt_vid;
    if (dp_mgmt_oob) {
        if (!dp->dp_mgmt.vid_fixed && !dp->dp_mgmt.port_fixed) {
            printf("WARNING:  dp_mgmt misconfig: OOB requires fixed port\n");
            printf("WARNING:  Removing OOB management\n");
            fprintf(stderr, "WARNING:  dp_mgmt misconfig: OOB requires "
                    "fixed port\n");
            fprintf(stderr, "WARNING:  Removing OOB management\n");
            dp_mgmt_oob = false;
        }
    }
    dp->dp_mgmt.oob = dp_mgmt_oob;
    dp_mgmt_set(dp);

    /* Get hw_desc/dp_desc from hw-lib if not set by command args */
    if (!hw_desc_set && dp->hw_drv != NULL && dp->hw_drv->hw_desc != NULL) {
        strncpy(hw_desc, dp->hw_drv->hw_desc, sizeof(hw_desc) - 1);
    }
    if (!dp_desc_set && dp->hw_drv != NULL && dp->hw_drv->dp_desc != NULL) {
        strncpy(dp->dp_desc, dp->hw_drv->dp_desc, sizeof(dp->dp_desc) - 1);
    }
#endif

    n_listeners = 0;
    for (i = optind; i < argc; i++) {
        const char *pvconn_name = argv[i];
        struct pvconn *pvconn;
        int retval;

        retval = pvconn_open(pvconn_name, &pvconn);
        if (!retval || retval == EAGAIN) {
            dp_add_pvconn(dp, pvconn);
            n_listeners++;
        } else {
            ofp_error(retval, "opening %s", pvconn_name);
        }
    }
    if (!n_listeners) {
        OFP_FATAL(0, "could not listen for any connections");
    }

    if (port_list) {
        add_ports(dp, port_list);
    }
    if (max_port_set) {
        printf("Adding port range %d to %d\n", min_port, max_port);
        add_ports_range(dp, min_port, max_port);
    }
    if (local_port) {
        printf("Adding local port\n");
        error = dp_add_local_port(dp, local_port, 0);
        if (error) {
            OFP_FATAL(error, "failed to add local port %s", local_port);
        }
    }

    error = vlog_server_listen(NULL, NULL);
    if (error) {
        OFP_FATAL(error, "could not listen for vlog connections");
    }

    die_if_already_running();
    daemonize();

    WATCHDOG_START;

    dp->rx_enabled = 1;
    printf("Entering event loop");
    for (;;) {
        WATCHDOG_STROKE;
        dp_run(dp);
        dp_wait(dp);
        poll_block();
    }

    WATCHDOG_STOP;

    return 0;
}

static void
add_ports(struct datapath *dp, char *port_list)
{
    char *port, *save_ptr;

    /* Glibc 2.7 has a bug in strtok_r when compiling with optimization that
     * can cause segfaults here:
     * http://sources.redhat.com/bugzilla/show_bug.cgi?id=5614.
     * Using ",," instead of the obvious "," works around it. */
    for (port = strtok_r(port_list, ",,", &save_ptr); port;
         port = strtok_r(NULL, ",,", &save_ptr)) {
        int error = dp_add_port(dp, port, num_queues);
        if (error) {
            ofp_fatal(error, "failed to add port %s", port);
        }
    }
}

/* Add a range of numeric ports from min to max, inclusive */
static void
add_ports_range(struct datapath *dp, int min_port, int max_port)
{
    char port_name[16];
    int port;
    int error;

    for (port = min_port; port <= max_port; port++) {
        sprintf(port_name, "%d", port);
        error = dp_add_port(dp, port_name, num_queues);
        if (error) {
            ofp_fatal(error, "failed to add port %s", port_name);
        }
    }
}

static void
parse_options(int argc, char *argv[])
{
    char dpid_str[17];
    int dpid_len;

    enum {
        OPT_MFR_DESC = UCHAR_MAX + 1,
        OPT_HW_DESC,
        OPT_SW_DESC,
        OPT_DP_DESC,
        OPT_SERIAL_NUM,
        OPT_BOOTSTRAP_CA_CERT,
        OPT_NO_LOCAL_PORT,
        OPT_NO_SLICING,
        OPT_DP_MGMT,
        OPT_DP_MGMT_OOB,
        OPT_DP_MGMT_PORT,
        OPT_DP_MGMT_VID,
        OPT_PORT_ADD_STATE
    };

    static struct option long_options[] = {
        {"interfaces",  required_argument, 0, 'i'},
        {"local-port",  required_argument, 0, 'L'},
        {"no-local-port", no_argument, 0, OPT_NO_LOCAL_PORT},
        {"datapath-id", required_argument, 0, 'd'},
        {"mgmt-mac",    required_argument, 0, 'e'}, /* for ether addr */
        {"verbose",     optional_argument, 0, 'v'},
        {"help",        no_argument, 0, 'h'},
        {"version",     no_argument, 0, 'V'},
        {"no-slicing",  no_argument, 0, OPT_NO_SLICING},
        {"mfr-desc",    required_argument, 0, OPT_MFR_DESC},
        {"hw-desc",     required_argument, 0, OPT_HW_DESC},
        {"sw-desc",     required_argument, 0, OPT_SW_DESC},
        {"dp_desc",  required_argument, 0, OPT_DP_DESC},
        {"serial_num",  required_argument, 0, OPT_SERIAL_NUM},
        {"min-port",  required_argument, 0, 'm'},
        {"max-port",  required_argument, 0, 'M'},
        {"dp-mgmt",  no_argument, 0, OPT_DP_MGMT},
        {"dp-mgmt-oob",  no_argument, 0, OPT_DP_MGMT_OOB},
        {"dp-mgmt-port",  required_argument, 0, OPT_DP_MGMT_PORT},
        {"dp-mgmt-vid",  required_argument, 0, OPT_DP_MGMT_VID},
        {"add-port-state",  required_argument, 0, OPT_PORT_ADD_STATE},
        WATCHDOG_LONG_OPTIONS
        DAEMON_LONG_OPTIONS,
#ifdef HAVE_OPENSSL
        VCONN_SSL_LONG_OPTIONS
        {"bootstrap-ca-cert", required_argument, 0, OPT_BOOTSTRAP_CA_CERT},
#endif
        {0, 0, 0, 0},
    };
    char *short_options = long_options_to_short_options(long_options);

    for (;;) {
        int indexptr;
        int c;
        uint8_t *ea;

        c = getopt_long(argc, argv, short_options, long_options, &indexptr);
        if (c == -1) {
            break;
        }

        switch (c) {
        case 'e': /* Management mac address */
            if (str_to_mac(optarg, dp_mac) != 0) {
                printf("Warning:  Could not parse mac address %s\n", optarg);
            } else {
                got_mac = true;
            }
            ea = dp_mac;
            printf("Datapath MAC: %02x:%02x:%02x:%02x:%02x:%02x\n",
                   ea[0], ea[1], ea[2], ea[3], ea[4], ea[5]);
            break;
        case 'd':

            dpid_len = strlen(optarg);
            if (dpid_len > 16) {
                /* If leading 0, truncate left; else truncate right */
                if (optarg[0] == '0') {
                    strncpy(dpid_str, &optarg[dpid_len-16], sizeof(dpid_str));
                } else {
                    strncpy(dpid_str, optarg, sizeof(dpid_str));
                }
                dpid_str[17] = 0;
                printf("Warning:  Truncating dpid string to %s\n", dpid_str);
            } else {
                strncpy(dpid_str, optarg, sizeof(dpid_str));
            }

            if (strspn(dpid_str, "0123456789abcdefABCDEF") != 
                    strlen(dpid_str)) {
                printf("Warning:  Illegal DPID string %s. Will generate\n",
                       optarg);
            } else {
                dpid = strtoll(dpid_str, NULL, 16);
                if (dpid != 0) {
                    printf("Using dpid: %s\n", dpid_str);
                } else {
                    printf("DPID is 0.  Will generate\n");
                }
            }
            break;

        case 'h':
            usage();

        case 'V':
            printf("%s %s compiled "__DATE__" "__TIME__"\n",
                   program_name, VERSION BUILDNR);
            exit(EXIT_SUCCESS);

        case 'v':
            vlog_set_verbosity(optarg);
            break;

        case 'i':
            if (!port_list) {
                port_list = optarg;
            } else {
                port_list = xasprintf("%s,%s", port_list, optarg);
            }
            break;

        case 'L':
            local_port = optarg;
            break;

            /* Support specifying a range of ports */
        case 'm':
            min_port = strtoul(optarg, NULL, 10);
            break;
        case 'M':
            max_port = strtoul(optarg, NULL, 10);
            max_port_set = true;
            break;

#if defined(WATCHDOG_SUPPORT)
        case 'w':
            watchdog_active = 1;
            break;
#endif
        case OPT_NO_LOCAL_PORT:
            local_port = NULL;
            break;

        case OPT_MFR_DESC:
            strncpy(mfr_desc, optarg, sizeof mfr_desc);
            break;

        case OPT_HW_DESC:
            hw_desc_set = true;
            strncpy(hw_desc, optarg, sizeof hw_desc);
            break;

        case OPT_SW_DESC:
            strncpy(sw_desc, optarg, sizeof sw_desc);
            break;

        case OPT_DP_DESC:
            dp_desc_set = true;
            strncpy(dp_desc, optarg, sizeof dp_desc);
            break;

        case OPT_SERIAL_NUM:
            strncpy(serial_num, optarg, sizeof serial_num);
            break;

        case OPT_NO_SLICING:
            num_queues = 0;
            break;

        case OPT_DP_MGMT:
            dp_mgmt = true;
            break;

        case OPT_DP_MGMT_OOB:
            dp_mgmt_oob = true;
            dp_mgmt = true;
            break;

        case OPT_DP_MGMT_PORT:
            dp_mgmt_port = strtoul(optarg, NULL, 10);
            dp_mgmt_port_fixed = true;
            dp_mgmt = true;
            break;

        case OPT_DP_MGMT_VID:
            dp_mgmt_vid = strtoul(optarg, NULL, 10);
            dp_mgmt_vid_fixed = true;
            dp_mgmt = true;
            break;

        case OPT_PORT_ADD_STATE:
            port_add_state = strtoul(optarg, NULL, 10);
            if (port_add_state == PORT_ADD_STATE_DOWN) {
                printf("Warning:  Add port state is disabled\n");
            }
            break;

        DAEMON_OPTION_HANDLERS

#ifdef HAVE_OPENSSL
        VCONN_SSL_OPTION_HANDLERS

        case OPT_BOOTSTRAP_CA_CERT:
            vconn_ssl_set_ca_cert_file(optarg, true);
            break;
#endif

        case '?':
            exit(EXIT_FAILURE);

        default:
            abort();
        }
    }
    free(short_options);
}

static void
usage(void)
{
    printf("%s: userspace OpenFlow datapath\n"
           "usage: %s [OPTIONS] LISTEN...\n"
           "where LISTEN is a passive OpenFlow connection method on which\n"
       "to listen for incoming connections from the secure channel.\n",
           program_name, program_name);
    vconn_usage(false, true, false);
    printf("\nConfiguration options:\n"
           "  -i, --interfaces=NETDEV[,NETDEV]...\n"
           "                          add specified initial switch ports\n"
           "  -m, --min-port=N        Set min port number in a range\n"
           "  -M, --max-port=N        Set max port number in a range\n"
           "  -L, --local-port=NETDEV set network device for local port\n"
           "  --no-local-port         disable local port\n"
           "  -d, --datapath-id=ID    Use ID as the OpenFlow switch ID\n"
           "                          (ID must consist of 12 hex digits)\n"
           "  --no-slicing            disable slicing\n"
           "  --dp-mgmt               Enable dataplane mgmt\n"
           "  --dp-mgmt-port=N        Set DP mgmt port (default 1)\n"
           "  --add-port-state=N      If 0, disable ports when added\n"
           "  --no-slicing            disable slicing\n"
           "\nOther options:\n"
           "  -D, --detach            run in background as daemon\n"
           "  -P, --pidfile[=FILE]    create pidfile (default: %s/udatapath.pid)\n"
           "  -f, --force             with -P, start even if already running\n"
           "  -v, --verbose=MODULE[:FACILITY[:LEVEL]]  set logging levels\n"
           "  -v, --verbose           set maximum verbosity level\n"
           "  -h, --help              display this help message\n"
           WATCHDOG_USAGE
           "  -V, --version           display version information\n",
        ofp_rundir);
    exit(EXIT_SUCCESS);
}
