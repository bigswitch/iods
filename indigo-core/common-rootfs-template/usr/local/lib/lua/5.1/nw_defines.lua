-- Copyright (c) 2011 Big Switch Networks
-- nw_defines.lua
-- Generic defines related to networkig

Network = Network or {}

Network.nw_proto_map = {
   [0] = "IPv6 Hop-by-Hop",
   [1] = "ICMP",
   [2] = "IGMP",
   [3] = "GGP",
   [4] = "IP in IP",
   [5] = "Stream Protocol",
   [6] = "TCP",
   [7] = "CBT",
   [8] = "EGP",
   [9] = "IGP",
   [10] = "BBN RCC Monitoring",
   [11] = "Network Voice Protocol",
   [12] = "Xerox PUP",
   [13] = "ARGUS",
   [14] = "EMCON",
   [15] = "Cross Net Debugger",
   [16] = "CHAOS",
   [17] = "UDP",
   [18] = "MUX",
   [19] = "DCN Measurement Subsystems",
   [20] = "Host Monitoring Protocol",
   [21] = "Packet Radio Measurement",
   [22] = "XEROX NS IDP",
   [23] = "Trunk-1",
   [24] = "Trunk-2",
   [25] = "Leaf-1",
   [26] = "Leaf-2",
   [27] = "RDP",
   [28] = "Internet Reliable Transaction",
   [29] = "ISO Transport Protocol 4",
   [30] = "Bulk Data Transfer",
   [31] = "MFE Network Services",
   [32] = "MERIT Internodal",
   [33] = "Datagram Congestion Control Protocol",
   [34] = "3PC     Third Party Connect Protocol",
   [35] = "Inter-Domain Policy Routing",
   [36] = "Xpress Transport Protocol",
   [37] = "Datagram Delivery Protocol",
   [38] = "IDPR Control Message Transport",
   [39] = "TP++ Transport Protocol",
   [40] = "IL Transport Protocol",
   [41] = "IPv6 encapsulation",
   [42] = "Source Demand Routing Protocol",
   [43] = "Routing Header for IPv6",
   [44] = "Fragment Header for IPv6",
   [45] = "Inter-Domain Routing Protocol",
   [46] = "RSVP",
   [47] = "GRE",
   [48] = "Mobile Host Routing Protocol",
   [49] = "BNA",
   [50] = "Encapsulating Security Payload",
   [51] = "Authentication Header",
   [52] = "Integrated Net Layer Security Protocol",
   [53] = "SwIPe IP with Encryption",
   [54] = "NBMA Address Resolution Protocol",
   [55] = "IP Mobility",
   [56] = "Transport Layer Security",
   [57] = "Simple Key-Management for IP",
   [58] = "IPv6-ICMP",
   [59] = "IPv6-NoNxt  No Next Header",
   [60] = "IPv6-Opts   Destination Options",
   [61] = "Any host internal protocol",
   [62] = "CFTP",
   [63] = "Any local network",
   [64] = "SATNET and Backroom EXPAK",
   [65] = "Kryptolan",
   [66] = "MIT Remote Virtual Disk Protocol",
   [67] = "Internet Pluribus Packet Core",
   [68] = "Any distributed file system",
   [69] = "SATNET Monitoring",
   [70] = "VISA Protocol",
   [71] = "Internet Packet Core Utility",
   [72] = "Computer Protocol Network Executive",
   [73] = "Computer Protocol Heart Beat",
   [74] = "Wang Span Network",
   [75] = "Packet Video Protocol",
   [76] = "Backroom SATNET Monitoring",
   [77] = "SUN ND PROTOCOL-Temporary",
   [78] = "WIDEBAND Monitoring",
   [79] = "WIDEBAND EXPAK",
   [80] = "Intl Org for Standardization IP",
   [81] = "Versatile Message Transaction Protocol",
   [82] = "Secure Versatile Message Transaction",
   [83] = "VINES",
   [84] = "TTP",
   [84] = "Internet Protocol Traffic Manager",
   [85] = "NSFNET-IGP",
   [86] = "Dissimilar Gateway Protocol",
   [87] = "TCF",
   [88] = "EIGRP",
   [89] = "OSPF",
   [90] = "Sprite-RPC",
   [91] = "Locus Address Resolution Protocol",
   [92] = "Multicast Transport Protocol",
   [93] = "AX.25",
   [94] = "IP-within-IP Encapsulation Protocol",
   [95] = "Mobile Internetworking Control",
   [96] = "Semaphore Communications Sec. Pro",
   [97] = "Ethernet-within-IP Encapsulation",
   [98] = "Encapsulation Header",
   [99] = "Any private encryption scheme",
   [100] = "GMTP",
   [101] = "Ipsilon Flow Management Protocol",
   [102] = "PNNI over IP",
   [103] = "Protocol Independent Multicast",
   [104] = "IBM Aggregate Route IP Switching",
   [105] = "Space Communications Protocol",
   [106] = "QNX",
   [107] = "Active Networks",
   [108] = "IP Payload Compression Protocol",
   [109] = "Sitara Networks Protocol",
   [110] = "Compaq Peer Protocol",
   [111] = "IPX in IP",
   [112] = "Virtual Router Redundancy",
   [113] = "PGM Reliable Transport",
   [114] = "Any 0-hop protocol",
   [115] = "Layer Two Tunneling Protocol",
   [116] = "D-II Data Exchange (DDX)",
   [117] = "Interactive Agent Transfer Protocol",
   [118] = "Schedule Transfer Protocol",
   [119] = "SpectraLink Radio Protocol",
   [120] = "UTI",
   [121] = "Simple Message Protocol",
   [122] = "SM",
   [123] = "Performance Transparency Protocol",
   [124] = "IS-IS over IPv4",
   [125] = "FIRE",
   [126] = "Combat Radio Transport Protocol",
   [127] = "Combat Radio User Datagram",
   [128] = "SSCOPMCE",
   [129] = "IPLT",
   [130] = "Secure Packet Shield",
   [131] = "Private IP Encap within IP",
   [132] = "SCTP",
   [133] = "Fibre Channel",
   [134] = "RSVP-E2E-IGNORE",
   [135] = "Mobility Header",
   [136] = "UDP Lite",
   [137] = "MPLS-in-IP",
   [138] = "MANET Protocols",
   [139] = "Host Identity Protocol",
   [140] = "Site Multihoming by IPv6"
}

Network.dl_type_map = {
   [0x0800] = "IPv4",
   [0x0806] = "ARP",
   [0x0842] = "Wake-on-LAN Magic Packet",
   [0x1337] = "SYNdog",
   [0x6003] = "DECnet Phase IV",
   [0x8035] = "RARP",
   [0x809B] = "Ethertalk",
   [0x80F3] = "AARP",
   [0x8100] = "VLAN IEEE 802.1Q",
   [0x8137] = "Novell IPX",
   [0x8138] = "Novell",
   [0x8204] = "QNX Qnet",
   [0x86DD] = "IPv6",
   [0x8808] = "MAC Control",
   [0x8809] = "Slow protos; IEEE 802.3",
   [0x8819] = "CobraNet",
   [0x8847] = "MPLS unicast",
   [0x8848] = "MPLS multicast",
   [0x8863] = "PPPoE Discovery Stage",
   [0x8864] = "PPPoE Session Stage",
   [0x886F] = "MS NLB heartbeat [3]",
   [0x8870] = "Jumbo Frame",
   [0x887B] = "HomePlug 1.0 MME",
   [0x888E] = "EAP over LAN (IEEE 802.1X)",
   [0x8892] = "PROFINET Protocol",
   [0x889A] = "HyperSCSI (SCSI over Ethernet)",
   [0x88A2] = "ATA over Ethernet",
   [0x88A4] = "EtherCAT Protocol",
   [0x88A8] = "Provider Bridging (IEEE 802.1ad)",
   [0x88AB] = "Ethernet Powerlink",
   [0x88CC] = "LLDP",
   [0x88CD] = "SERCOS III",
   [0x88D8] = "Circuit Emulation (MEF-8)",
   [0x88E1] = "HomePlug AV MME",
   [0x88E5] = "MAC security (IEEE 802.1AE)",
   [0x88F7] = "Precision Time Protocol (IEEE 1588)",
   [0x8902] = "IEEE 802.1ag Fault Management Protocol",
   [0x8906] = "Fibre Channel over Ethernet",
   [0x8914] = "FCoE Initialization Protocol",
   [0x9000] = "Configuration Test Protocol",
   [0x9100] = "Q-in-Q",
   [0xCAFE] = "Veritas Low Latency Transport"
}
