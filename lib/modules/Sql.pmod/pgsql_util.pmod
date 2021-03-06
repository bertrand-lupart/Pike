/*
 * Some pgsql utility functions.
 * They are kept here to avoid circular references.
 *
 */

#pike __REAL_VERSION__

#include "pgsql.h"

#define FLUSH		"H\0\0\0\4"

//! Some pgsql utility functions

class PGassist
{ int(-1..1) peek(int timeout) { }

  string read(int len,void|int(0..1) not_all) { }

  int write(string|array(string) data) { }

  int getchar() { }

  int close() { }

  private final array(string) cmdbuf=({});

#ifdef USEPGsql
  inherit _PGsql.PGsql;
#else
  object portal;

  void setportal(void|object newportal)
  { portal=newportal;
  }

  inline int(-1..1) bpeek(int timeout)
  { return peek(timeout);
  }

  int flushed=-1;

  inline final int getbyte()
  { if(!flushed && !bpeek(0))
      sendflush();
    return getchar();
  }

  final string getstring(void|int len)
  { String.Buffer acc=String.Buffer();
    if(!zero_type(len))
    { string res;
      do
      { if(!flushed && !bpeek(0))
	  sendflush();
	res=read(len,!flushed);
	if(res)
	{ if(!sizeof(res))
	    return acc->get();
	  acc->add(res);
	}
      }
      while(sizeof(acc)<len&&res);
      return sizeof(acc)?acc->get():res;
    }
    int c;
    while((c=getbyte())>0)
      acc->putchar(c);
    return acc->get();
  }

  inline final int getint16()
  { int s0=getbyte();
    int r=(s0&0x7f)<<8|getbyte();
    return s0&0x80 ? r-(1<<15) : r ;
  }

  inline final int getint32()
  { int r=getint16();
    r=r<<8|getbyte();
    return r<<8|getbyte();
  }

  inline final int getint64()
  { int r=getint32();
    return r<<32|getint32()&0xffffffff;
  }
#endif

  inline final string plugbyte(int x)
  { return String.int2char(x&255);
  }

  inline final string plugint16(int x)
  { return sprintf("%c%c",x>>8&255,x&255);
  }

  inline final string plugint32(int x)
  { return sprintf("%c%c%c%c",x>>24&255,x>>16&255,x>>8&255,x&255);
  }

  inline final string plugint64(int x)
  { return sprintf("%c%c%c%c%c%c%c%c",x>>56&255,x>>48&255,x>>40&255,x>>32&255,
     x>>24&255,x>>16&255,x>>8&255,x&255);
  }

  final void sendflush()
  { sendcmd(({}),1);
  }

  final void sendcmd(string|array(string) data,void|int flush)
  { if(arrayp(data))
      cmdbuf+=data;
    else
      cmdbuf+=({data});
    switch(flush)
    { case 3:
	cmdbuf+=({FLUSH});
	flushed=1;
	break;
      default:
	flushed=0;
	break;
      case 1:
	cmdbuf+=({FLUSH});
	PD("Flush\n");
      case 2:
	flushed=1;
	{ int i=write(cmdbuf);
	  if(portal && portal._pgsqlsess)
	  { portal._pgsqlsess._packetssent++;
	    portal._pgsqlsess._bytessent+=i;
	  }
	}
	cmdbuf=({});
    }
  }

  final void sendterminate()
  { PD("Terminate\n");
    sendcmd(({"X",plugint32(4)}),2);
    close();
  }

  void create()
  {
#ifdef USEPGsql
    ::create();
#endif
  }
}

class PGconn
{ inherit PGassist:pg;
#ifdef UNBUFFEREDIO
  inherit Stdio.File:std;

  inline int getchar()
  { return std::read(1)[0];
  }
#else
  inherit Stdio.FILE:std;

  inline int getchar()
  { return std::getchar();
  }
#endif

  inline int(-1..1) peek(int timeout)
  { return std::peek(timeout);
  }

  inline string read(int len,void|int(0..1) not_all)
  { return std::read(len,not_all);
  }

  inline int write(string|array(string) data)
  { return std::write(data);
  }

  int close()
  { return std::close();
  }

  void create(Stdio.File stream,object t)
  { std::create();
    std::assign(stream);
    pg::create();
  }
}

#if constant(SSL.sslfile)
class PGconnS
{ inherit SSL.sslfile:std;
  inherit PGassist:pg;

  Stdio.File rawstream;

  inline int(-1..1) peek(int timeout)
  { return rawstream.peek(timeout);			    // This is a kludge
  }			 // Actually SSL.sslfile should provide a peek() method

  inline string read(int len,void|int(0..1) not_all)
  { return std::read(len,not_all);
  }

  inline int write(string|array(string) data)
  { return std::write(data);
  }

  void create(Stdio.File stream, SSL.context ctx)
  { rawstream=stream;
    std::create(stream,ctx,1,1);
    pg::create();
  }
}
#endif

//! The result object returned by @[Sql.pgsql()->big_query()], except for
//! the noted differences it behaves the same as @[Sql.sql_result].
//!
//! @seealso
//!   @[Sql.sql_result], @[Sql.pgsql], @[Sql.Sql], @[Sql.pgsql()->big_query()]
class pgsql_result {

object _pgsqlsess;
private int numrows;
private int eoffound;
private mixed delayederror;
private int copyinprogress;
int _fetchlimit;
int _alltext;
int _forcetext;

#ifdef NO_LOCKING
int _qmtxkey;
#else
Thread.MutexKey _qmtxkey;
#endif

string _portalname;

int _bytesreceived;
int _rowsreceived;
int _interruptable;
int _inflight;
int _portalbuffersize;
array _params;
string _statuscmdcomplete;
string _query;
array(array(mixed)) _datarows;
array(mapping(string:mixed)) _datarowdesc=({});
array(int) _datatypeoid;
#ifdef USEPGsql
int _buffer;
#endif

private object fetchmutex;

protected string _sprintf(int type, void|mapping flags)
{ string res=UNDEFINED;
  switch(type)
  { case 'O':
      res=sprintf("pgsql_result  numrows: %d  eof: %d  querylock: %d"
       " inflight: %d\nportalname: %O  datarows: %d  laststatus: %s\n",
       numrows,eoffound,!!_qmtxkey,_inflight,
       _portalname,sizeof(_datarowdesc),
       _statuscmdcomplete||"");
      break;
  }
  return res;
}

void create(object pgsqlsess,string query,int fetchlimit,
 int portalbuffersize,int alltyped,array params,int forcetext)
{ _pgsqlsess = pgsqlsess;
  _query = query;
  _datarows = ({ }); numrows = UNDEFINED;
  fetchmutex = Thread.Mutex();
  _fetchlimit=forcetext?0:fetchlimit;
  _portalbuffersize=portalbuffersize;
  _alltext = !alltyped;
  _params = params;
  _forcetext = forcetext;
  steallock();
}

//! Returns the command-complete status for this query.
//!
//! @seealso
//!  @[affected_rows()]
//!
//! @note
//! This function is PostgreSQL-specific, and thus it is not available
//! through the generic SQL-interface.
string status_command_complete()
{ return _statuscmdcomplete;
}

//! Returns the number of affected rows by this query.
//!
//! @seealso
//!  @[status_command_complete()]
//!
//! @note
//! This function is PostgreSQL-specific, and thus it is not available
//! through the generic SQL-interface.
int affected_rows()
{ int rows;
  if(_statuscmdcomplete)
    sscanf(_statuscmdcomplete,"%*s %d",rows);
  return rows;
}

//! @seealso
//!  @[Sql.sql_result()->num_fields()]
int num_fields()
{ return sizeof(_datarowdesc);
}

//! @seealso
//!  @[Sql.sql_result()->num_rows()]
int num_rows()
{ int numrows;
  if(_statuscmdcomplete)
    sscanf(_statuscmdcomplete,"%*s %d",numrows);
  return numrows;
}

//! @seealso
//!  @[Sql.sql_result()->eof()]
int eof()
{ return eoffound;
}

//! @seealso
//!  @[Sql.sql_result()->fetch_fields()]
array(mapping(string:mixed)) fetch_fields()
{ return _datarowdesc+({});
}

private void releasesession()
{ if(_pgsqlsess)
  { if(copyinprogress)
    { PD("CopyDone\n");
      _pgsqlsess._c.sendcmd("c\0\0\0\4",1);
    }
    if(_pgsqlsess.is_open())
      _pgsqlsess.resync(2);
  }
  _qmtxkey=UNDEFINED;
  _pgsqlsess=UNDEFINED;
}

void destroy()
{ catch				   // inside destructors, exceptions don't work
  { releasesession();
  };
}

inline private array(mixed) getdatarow()
{ array(mixed) datarow=_datarows[0];
  _datarows=_datarows[1..];
  return datarow;
}

private void steallock()
{
#ifndef NO_LOCKING
  PD("Going to steal oldportal %d\n",!!_pgsqlsess._c.portal);
  Thread.MutexKey stealmtxkey = _pgsqlsess._stealmutex.lock();
  do
    if(_qmtxkey = _pgsqlsess._querymutex.current_locking_key())
    { pgsql_result portalb;
      if(portalb=_pgsqlsess._c.portal)
      { _pgsqlsess._nextportal++;
	if(portalb->_interruptable)
	  portalb->fetch_row(2);
	else
	{ PD("Waiting for the querymutex\n");
	  if((_qmtxkey=_pgsqlsess._querymutex.lock(2)))
	  { if(copyinprogress)
	      error("COPY needs to be finished first\n");
	    error("Driver bug, please report, "
	     "conflict while interleaving SQL-operations\n");
	  }
	  PD("Got the querymutex\n");
	}
	_pgsqlsess._nextportal--;
      }
      break;
    }
  while(!(_qmtxkey=_pgsqlsess._querymutex.trylock()));
#else
  PD("Skipping lock\n");
  _qmtxkey=1;
#endif
  _pgsqlsess._c.setportal(this);
  PD("Stealing successful\n");
}

//! @decl array(mixed) fetch_row()
//! @decl void fetch_row(string|array(string) copydatasend)
//!
//! @returns
//!  One result row at a time.
//!
//! When using COPY FROM STDOUT, this method returns one row at a time
//! as a single string containing the entire row.
//!
//! @param copydatasend
//! When using COPY FROM STDIN, this method accepts a string or an
//! array of strings to be processed by the COPY command; when sending
//! the amount of data sent per call does not have to hit row or column
//! boundaries.
//!
//! The COPY FROM STDIN sequence needs to be completed by either
//! explicitly or implicitly destroying the result object, or by passing a
//! zero argument to this method.
//!
//! @seealso
//!  @[eof()]
array(mixed) fetch_row(void|int|string|array(string) buffer)
{
#ifndef NO_LOCKING
  Thread.MutexKey fetchmtxkey = fetchmutex.lock();
#endif
  if(!buffer && sizeof(_datarows))
    return getdatarow();
  if(copyinprogress)
  { fetchmtxkey = UNDEFINED;
    if(stringp(buffer) || arrayp(buffer))
    { int totalsize=4;
      if(arrayp(buffer))
	foreach(buffer;;string value)
	  totalsize+=sizeof(value);
      else
	totalsize+=sizeof(buffer),buffer=({buffer});
      PD("CopyData\n");
      _pgsqlsess._c.sendcmd(
       ({"d",_pgsqlsess._c.plugint32(totalsize)})+buffer,2);
    }
    else
      releasesession();
    return UNDEFINED;
  }
  mixed err;
  if(buffer!=2 && (err=delayederror))
  { delayederror=UNDEFINED;
    throw(err);
  }
  err = catch
  { if(_portalname)
    { if(buffer!=2 && !_qmtxkey)
      { steallock();
	if(_fetchlimit)
	  _pgsqlsess._sendexecute(_fetchlimit);
      }
      while(_pgsqlsess._closesent)
	_pgsqlsess._decodemsg();	      // Flush previous portal sequence
      for(;;)
      {
#ifdef DEBUGMORE
	PD("buffer: %d	nextportal: %d	lock: %d\n",
	 buffer,_pgsqlsess._nextportal,!!_qmtxkey);
#endif
#ifdef USEPGsql
	_buffer=buffer;
#endif
	switch(_pgsqlsess._decodemsg())
	{ case copyinresponse:
	    copyinprogress=1;
	    return UNDEFINED;
	  case dataready:
	    _pgsqlsess._mstate=dataprocessed;
	    _rowsreceived++;
	    switch(buffer)
	    { case 0:
	      case 1:
		if(_fetchlimit)
		  _fetchlimit=
		   min(_portalbuffersize/2*_rowsreceived/_bytesreceived || 1,
		   _pgsqlsess._fetchlimit);
	    }
	    switch(buffer)
	    { case 2:
	      case 3:
		continue;
	      case 1:
		_interruptable=1;
		if(_pgsqlsess._nextportal)
		  continue;
#if STREAMEXECUTES
		if(_fetchlimit && _inflight<=_fetchlimit-1)
		  _pgsqlsess._sendexecute(_fetchlimit);
#endif
		return UNDEFINED;
	    }
#if STREAMEXECUTES
	    if(_fetchlimit && _inflight<=_fetchlimit-1)
	      _pgsqlsess._sendexecute(_fetchlimit);	    // Overlap Executes
#endif
	    return getdatarow();
	  case commandcomplete:
	    _inflight=0;
	    releasesession();
	    switch(buffer)
	    { case 1:
	      case 2:
		return UNDEFINED;
	      case 3:
		if(sizeof(_datarows))
		  return getdatarow();
	    }
	    break;
	  case portalsuspended:
	    if(_inflight)
	      continue;
	    if(_pgsqlsess._nextportal)
	    { switch(buffer)
	      { case 1:
		case 2:
		  _qmtxkey = UNDEFINED;
		  return UNDEFINED;
		case 3:
		  _qmtxkey = UNDEFINED;
		  return getdatarow();
	      }
	      _fetchlimit=FETCHLIMITLONGRUN;
	      if(sizeof(_datarows))
	      { _qmtxkey = UNDEFINED;
		return getdatarow();
	      }
	      buffer=3;
	    }
	    _pgsqlsess._sendexecute(_fetchlimit);
	  default:
	    continue;
	}
	break;
      }
    }
    eoffound=1;
    return UNDEFINED;
  };
  PD("Exception %O\n",err);
  _pgsqlsess.resync();
  if(buffer!=2)
    throw(err);
  if(!delayederror)
    delayederror=err;
  return UNDEFINED;
}

};
