//! Handling of Certifikate Signing Requests (PKCS-10)

#pike __REAL_VERSION__
// #pragma strict_types

#if constant(Crypto.RSA)

import Standards.ASN1.Types;

class CSR_Attributes
{
  inherit .Certificate.Attributes;
  constant cls = 2;
  constant tag = 0;
}

//!
Sequence build_csr(Crypto.RSA rsa, object name,
		   mapping(string:array(object)) attributes)
{
  Sequence info = Sequence( ({ Integer(0), name,
			       .RSA.build_public_key(rsa),
			       CSR_Attributes(.Identifiers.attribute_ids,
					      attributes) }) );
  return Sequence( ({ info,
		      Sequence(
			       ({ .Identifiers.rsa_md5_id, Null() }) ),
		      BitString(rsa->pkcs_sign(info->get_der(),
                                               Crypto.MD5)) }) );
}

#if 0
object build_csr_dsa(Crypto.DSA dsa, object name)
{
  Sequence info = Sequence( ({ Integer }) );
}
#endif

#else
constant this_program_does_not_exist=1;
#endif
