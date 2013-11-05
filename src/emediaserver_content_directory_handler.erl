-module(emediaserver_content_directory_handler).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

init(_Transport, Req, []) ->
  {ok, Req, undefined}.

handle(Req, State) ->
  {ok, Body} = content_directory_dtl:render([]),
  Headers = [{<<"Content-Type">>, <<"text/xml; charset=utf-8">>}],
  {ok, Req2} = cowboy_req:reply(200, Headers, Body, Req),
  {ok, Req2, State}.

terminate(_Reason, _Req, _State) ->
  ok.