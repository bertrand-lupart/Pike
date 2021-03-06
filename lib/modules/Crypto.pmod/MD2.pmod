#pike __REAL_VERSION__
#pragma strict_types

//! MD2 is a message digest function constructed by Burton Kaliski,
//! and is described in RFC 1319. It outputs message digests of 128
//! bits, or 16 octets.

#if constant(Nettle) && constant(Nettle.MD2)

inherit Nettle.MD2;

Standards.ASN1.Types.Identifier asn1_id()
{
  return Standards.PKCS.Identifiers.md2_id;
}

#else
constant this_program_does_not_exist=1;
#endif
