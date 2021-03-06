%% @author Gregoire Lejeune <gregoire.lejeune@free.fr>
%% @copyright 2013 Gregoire Lejeune
%% @doc This module allow you to acces the emedia configuration
-module(eme_config).

-behaviour(gen_server).

-include("../include/eme_config.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/0]).
-export([get/1, get/2]).

% wrappers

%% @doc Start the configuration server
start_link() -> 
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Access a configuration information
-spec(get/1 :: (hostname | uuid | ip | port | services | ffprobe_path | scan_interval | db_path | lang) -> any()).
get(hostname) ->
  gen_server:call(?MODULE, {get_hostname});
get(uuid) ->
  gen_server:call(?MODULE, {get_uuid});
get(ip) ->
  gen_server:call(?MODULE, {get_ip});
get(port) ->
  gen_server:call(?MODULE, {get_port});
get(services) ->
  gen_server:call(?MODULE, {get_services});
get(ffprobe_path) ->
  gen_server:call(?MODULE, {get_ffprobe_path});
get(ffmpeg_path) ->
  gen_server:call(?MODULE, {get_ffmpeg_path});
get(scan_interval) ->
  gen_server:call(?MODULE, {get_scan_interval});
get(db_path) ->
  gen_server:call(?MODULE, {get_db_path});
get(lang) ->
  gen_server:call(?MODULE, {get_lang}).
-spec(get/2 :: (medias, atom() | [atom()]) -> [string()]).
%% @doc Access a configuration information
get(medias, Type) ->
  gen_server:call(?MODULE, {get_medias, Type}).

% Server

%% @hidden
init([]) ->
  {ok, read_config()}.

%% @hidden
terminate(_Reason, _Config) -> 
  ok.

%% @hidden
handle_cast(_Message, Config) -> 
  {noreply, Config}.

%% @hidden
handle_info(_Message, Config) -> 
  {noreply, Config}.

%% @hidden
code_change(_OldVersion, Config, _Extra) -> 
  {ok, Config}.

%% @hidden
handle_call({get_hostname}, _From, Config) ->
  #emeconfig{hostname = Hostname} = Config,
  {reply, Hostname, Config};
handle_call({get_uuid}, _From, Config) ->
  #emeconfig{uuid = UUID} = Config,
  {reply, UUID, Config};
handle_call({get_ip}, _From, Config) ->
  #emeconfig{ip = TcpIP} = Config,
  {reply, TcpIP, Config};
handle_call({get_port}, _From, Config) ->
  #emeconfig{port = TcpPort} = Config,
  {reply, TcpPort, Config};
handle_call({get_services}, _From, Config) ->
  #emeconfig{services = Services} = Config,
  {reply, Services, Config};
handle_call({get_ffprobe_path}, _From, Config) ->
  #emeconfig{ffprobe_path = FFProbePath} = Config,
  {reply, FFProbePath, Config};
handle_call({get_ffmpeg_path}, _From, Config) ->
  #emeconfig{ffmpeg_path = FFMpegPath} = Config,
  {reply, FFMpegPath, Config};
handle_call({get_scan_interval}, _From, Config) ->
  #emeconfig{scan_interval = ScanInterval} = Config,
  {reply, ScanInterval, Config};
handle_call({get_db_path}, _From, Config) ->
  #emeconfig{db_path = DBPath} = Config,
  {reply, DBPath, Config};
handle_call({get_lang}, _From, Config) ->
  #emeconfig{lang = Lang} = Config,
  {reply, Lang, Config};
handle_call({get_medias, Type}, _From, Config) ->
  #emeconfig{medias = Medias} = Config,
  {reply, get_medias_type(Medias, Type), Config};
handle_call(_Message, _From, Config) ->
  {reply, error, Config}.

% private

get_medias_type(Medias, Types) when is_list(Types) ->
  lists:foldl(fun(Type, Acc) ->
        Acc ++ get_medias_type(Medias, Type)
    end, [], Types);
get_medias_type(Medias, Type) when is_atom(Type) ->
  lists:foldl(fun({MType, Path}, Acc) ->
        case MType of
          Type -> 
            Dir = case ucp:detect(Path) of
              utf8 -> ucp:from_utf8(Path);
              _ -> Path
            end,
            Acc ++ [efile:expand_path(Dir)];
          _ -> Acc
        end
    end, [], Medias).

read_config() ->
  lager:info("Check configuration"),
  {ok, Hostname} = inet:gethostname(),
  IP = case get_value(ip, ?EMEDIASERVER_IP) of
    ?EMEDIASERVER_IP -> inet_parse:ntoa(get_active_ip());
    Other -> Other
  end,
  Time = get_value(scan_interval, ?EMEDIASERVER_SCAN_INTERVAL) * 1000,
  ScanInterval = if 
    (Time > 0) and (Time < 4294967295) -> 
      Time;
    true -> 
      ?EMEDIASERVER_SCAN_INTERVAL * 1000
  end,
  #emeconfig{
    hostname = Hostname,
    uuid = uuid:generate(),
    ip = IP,
    port = get_value(port, ?EMEDIASERVER_TCP_PORT),
    services = get_value(services, ?EMEDIASERVER_SERVICES),
    medias = get_value(medias, []),
    scan_interval = ScanInterval,
    tmdb_api_key = get_value(tmdb_api_key, false),
    ffprobe_path = efile:expand_path(get_value(ffprobe_path, "ffprobe")),
    ffmpeg_path = efile:expand_path(get_value(ffmpeg_path, "ffmpeg")),
    db_path = efile:expand_path(get_value(db_path, ".")),
    lang = get_value(lang, en)
  }.

get_value(Key, Default) ->
  case application:get_env(eme_config, Key) of
    {ok, Value} -> Value;
    _ -> Default
  end.

get_active_ip() ->
  get_active_ip(get_iflist()).

get_active_ip(If_list) ->
  get_ip([A || A <- If_list, inet:ifget(A,[addr]) /= {ok,[{addr,{127,0,0,1}}]}, filter_networkcard(list_to_binary(A))]).

get_iflist() ->
  {ok, IfList} = inet:getiflist(),
  IfList.

filter_networkcard(<<"vnic", _R/binary>>) ->
  false;
filter_networkcard(<<"vmnet", _R/binary>>) ->
  false;
filter_networkcard(_) ->
  true.

get_ip([]) ->
  get_loopback();
get_ip([If]) ->
  case inet:ifget(If, [addr]) of
    {ok, []} -> get_loopback();
    {_, [{_, Ip}]} -> Ip
  end.

get_loopback() ->
  get_loopback(get_iflist()).

get_loopback(If_list) ->
  get_ip([A || A <- If_list, inet:ifget(A,[addr]) == {ok,[{addr,{127,0,0,1}}]}]).
