//
//  SupabaseClient.swift
//  Apollo
//
//  Created by Darius Ehsani on 5/9/26.
//

import Supabase

let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseAnonKey
)
