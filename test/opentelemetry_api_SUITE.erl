-module(opentelemetry_api_SUITE).

-compile(export_all).

-include_lib("stdlib/include/assert.hrl").
-include_lib("common_test/include/ct.hrl").

-include("opentelemetry.hrl").
-include("tracer.hrl").

all() ->
    [noop_tracer, update_span_data, noop_with_span, macros, can_create_link_from_span].

init_per_suite(Config) ->
    application:load(opentelemetry_api),
    Config.

end_per_suite(_Config) ->
    ok.

can_create_link_from_span(_Config) ->
  %% start a span to create a link to
  SpanCtx = ?start_span(<<"span-1">>),

  %% extract individual values from span context
  TraceId = ot_span:trace_id(SpanCtx),
  SpanId = ot_span:span_id(SpanCtx),
  Tracestate = ot_span:tracestate(SpanCtx),

  %% end span, so there's no current span set
  ?end_span(),

  %% we don't need any attributes for this test
  Attributes = [],

  %% attempt to create a link
  Link = opentelemetry:link(TraceId, SpanId, Attributes, Tracestate),
  ?assertMatch(#link{ trace_id = TraceId
                    , span_id = SpanId
                    , attributes = Attributes
                    , tracestate = Tracestate
                    }, Link).


noop_tracer(_Config) ->
    %% start a span and 2 children
    SpanCtx1 = ?start_span(<<"span-1">>),
    SpanCtx2 = ?start_span(<<"span-2">>),
    SpanCtx3 = ?start_span(<<"span-3">>),

    %% end the 3rd span
    ?assertMatch(SpanCtx3, ?current_span_ctx()),
    ?end_span(),

    %% 2nd span should be the current span ctx now
    ?assertMatch(SpanCtx2, ?current_span_ctx()),

    %% start another child of the 2nd span
    SpanCtx4 = ?start_span(<<"span-4">>),
    ?assertMatch(SpanCtx4, ?current_span_ctx()),

    %% end 4th span and 2nd should be current
    ?end_span(),
    ?assertMatch(SpanCtx2, ?current_span_ctx()),

    %% end 2th span and 1st should be current
    ?end_span(),
    ?assertMatch(SpanCtx1, ?current_span_ctx()),

    %% end first and no span should be current ctx
    ?end_span(),

    %% always returns a noop span
    ?assertMatch(SpanCtx1, ?current_span_ctx()).

%% just shouldn't crash
update_span_data(_Config) ->
    Links = [#link{trace_id=0,
                   span_id=0,
                   attributes=[],
                   tracestate=[]}],

    SpanCtx1 = ?start_span(<<"span-1">>, #{links => Links}),
    ?set_attribute(<<"key-1">>, <<"value-1">>),

    Events = opentelemetry:events([{opentelemetry:timestamp(),
                                    <<"timed-event-name">>, []}]),
    Status = opentelemetry:status(0, <<"status">>),

    %% with spanctx and tracer passed as an argument
    Tracer = opentelemetry:get_tracer(),
    ot_span:set_status(Tracer, SpanCtx1, Status),

    ot_span:add_events(Tracer, SpanCtx1, Events),

    ?assertMatch(SpanCtx1, ?current_span_ctx()),
    ?end_span(),

    ok.

noop_with_span(_Config) ->
    Tracer = opentelemetry:get_tracer(),
    ?assertMatch({ot_tracer_noop, _}, Tracer),

    Result = some_result,
    ?assertEqual(Result, ot_tracer:with_span(Tracer, <<"span1">>, fun(_) -> Result end)),
    ok.

macros(_Config) ->
    _SpanCtx1 = ?start_span(<<"span-1">>),
    SpanCtx2 = ?start_span(<<"span-2">>),

    ?assertMatch(SpanCtx2, ?current_span_ctx()),
    ?end_span(),

    %% 2nd span should be the current span ctx now
    ?assertMatch(SpanCtx2, ?current_span_ctx()).
