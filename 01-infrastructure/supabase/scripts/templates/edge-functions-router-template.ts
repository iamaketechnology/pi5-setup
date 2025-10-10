// Main Router for Supabase Edge Functions (Self-Hosted)
// This "fat function" routes requests to different Edge Functions
// Date: 10 Octobre 2025

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// CORS headers for all responses
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
};

// Helper to create Supabase client
function getSupabaseClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );
}

// Import handler functions
// NOTE: Since each function uses serve(), we'll need to inline the logic or refactor
// For now, we'll forward to the actual function files dynamically

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);

    // Extract function name from path
    // Expected: /verify-document, /create-access-link, etc.
    const path = url.pathname;
    console.log(`[Router] Incoming request: ${req.method} ${path}`);

    // Route to appropriate function based on path
    switch (path) {
      case '/verify-document':
        return await handleVerifyDocument(req);
      case '/create-access-link':
        return await handleCreateAccessLink(req);
      case '/generate-certificate':
        return await handleGenerateCertificate(req);
      case '/sign-document':
        return await handleSignDocument(req);
      case '/get-document-signatures':
        return await handleGetDocumentSignatures(req);
      case '/upload-document':
        return await handleUploadDocument(req);
      case '/delete-document':
        return await handleDeleteDocument(req);
      case '/send-document':
        return await handleSendDocument(req);
      case '/send-invite':
        return await handleSendInvite(req);
      case '/accept-invite':
        return await handleAcceptInvite(req);
      case '/cancel-email-change':
        return await handleCancelEmailChange(req);
      case '/delete-my-account':
        return await handleDeleteMyAccount(req);
      case '/export-my-data':
        return await handleExportMyData(req);
      case '/list-app-certifiers':
        return await handleListAppCertifiers(req);
      case '/list-signed-copies':
        return await handleListSignedCopies(req);
      case '/render-signed-copy':
        return await handleRenderSignedCopy(req);
      default:
        return new Response(
          JSON.stringify({
            success: false,
            error: `Unknown function: ${path}`,
            message: 'Function not found',
            available_functions: [
              '/verify-document',
              '/create-access-link',
              '/generate-certificate',
              '/sign-document',
              '/get-document-signatures',
              '/upload-document',
              '/delete-document',
              '/send-document',
              '/send-invite',
              '/accept-invite',
              '/cancel-email-change',
              '/delete-my-account',
              '/export-my-data',
              '/list-app-certifiers',
              '/list-signed-copies',
              '/render-signed-copy'
            ]
          }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
    }
  } catch (error) {
    console.error('[Router] Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : String(error)
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

// Handler function stubs - will be implemented by copying logic from individual functions
// For verify-document, we'll implement the full logic here

async function handleVerifyDocument(req: Request) {
  // Import the logic from verify-document/index.ts inline
  // NOTE: This is a TEMPORARY solution. Ideally, each function should export a handler.

  try {
    const supabase = getSupabaseClient();
    const { token } = await req.json();

    console.log('=== VERIFY DOCUMENT DEBUG ===');
    console.log('Token reçu:', token);

    // Get access link details with certificate
    const { data: accessLink, error: linkError } = await supabase
      .from('access_links')
      .select(`
        *,
        documents!inner (
          id,
          filename,
          mime_type,
          file_size,
          sha256,
          storage_key,
          created_at,
          certificates (
            id,
            cert_sha256,
            pdf_storage_key,
            created_at
          )
        )
      `)
      .eq('token', token)
      .single();

    if (linkError || !accessLink) {
      throw new Error('Access link not found');
    }

    // Check if link is expired
    if (new Date(accessLink.expires_at) < new Date()) {
      throw new Error('Access link has expired');
    }

    // Check if link is revoked
    if (accessLink.revoked_at) {
      throw new Error('Access link has been revoked');
    }

    // Check usage limits
    if (accessLink.max_uses && accessLink.used_count >= accessLink.max_uses) {
      throw new Error('Access link usage limit exceeded');
    }

    // Get certificate
    let finalCertificate = null;
    if (accessLink.documents.certificates && accessLink.documents.certificates.length > 0) {
      finalCertificate = accessLink.documents.certificates[0];
    } else {
      finalCertificate = {
        id: 'temp-cert-' + accessLink.doc_id,
        cert_sha256: 'no-certificate-available',
        pdf_storage_key: null,
        created_at: new Date().toISOString()
      };
    }

    // Fetch certifiers
    const { data: certRows } = await supabase
      .from('document_certifications')
      .select('user_id, created_at')
      .eq('doc_id', accessLink.doc_id)
      .order('created_at', { ascending: true });

    let certifiers: Array<any> = [];
    if (certRows && certRows.length > 0) {
      const userIds = certRows.map((r: any) => r.user_id);
      const { data: profiles } = await supabase
        .from('profiles')
        .select('user_id, name, email')
        .in('user_id', userIds);

      const profileMap = new Map(
        (profiles || []).map((p: any) => [p.user_id, p])
      );

      certifiers = certRows.map((r: any) => {
        const p = profileMap.get(r.user_id) || { name: null, email: null };
        return {
          user_id: r.user_id,
          name: p.name ?? null,
          email: p.email ?? null,
          created_at: r.created_at,
        };
      });
    }

    // Increment usage count
    await supabase
      .from('access_links')
      .update({ used_count: accessLink.used_count + 1 })
      .eq('id', accessLink.id);

    // Log access
    const clientIP = req.headers.get('cf-connecting-ip') ||
                     req.headers.get('x-forwarded-for') ||
                     'unknown';

    await supabase
      .from('audit_logs')
      .insert({
        action: 'document_accessed',
        doc_id: accessLink.doc_id,
        link_id: accessLink.id,
        ip_hash: btoa(clientIP),
        user_agent: req.headers.get('User-Agent') || 'unknown'
      });

    // Generate signed URLs
    let documentUrl = null;
    let certificateUrl = null;

    try {
      const { data: docUrlData } = await supabase.storage
        .from('documents')
        .createSignedUrl(accessLink.documents.storage_key, 3600);
      documentUrl = docUrlData?.signedUrl || null;
    } catch (error) {
      console.error('Failed to create signed URL for document:', error);
    }

    if (finalCertificate.pdf_storage_key) {
      try {
        const { data: certUrlData } = await supabase.storage
          .from('certificates')
          .createSignedUrl(finalCertificate.pdf_storage_key, 3600);
        certificateUrl = certUrlData?.signedUrl || null;
      } catch (error) {
        console.error('Failed to create signed URL for certificate:', error);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        document: accessLink.documents,
        certificate: {
          id: finalCertificate.id,
          cert_sha256: finalCertificate.cert_sha256,
          pdf_storage_key: finalCertificate.pdf_storage_key,
          created_at: finalCertificate.created_at
        },
        access_link: {
          scope: accessLink.scope,
          expires_at: accessLink.expires_at,
          max_uses: accessLink.max_uses,
          used_count: accessLink.used_count + 1
        },
        certifiers,
        download_urls: {
          document: documentUrl,
          certificate: certificateUrl
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    );

  } catch (error: any) {
    let errorMessage = 'Document verification failed';
    let statusCode = 400;

    if (error.message.includes('not found')) {
      errorMessage = 'Document not found or access link invalid';
      statusCode = 404;
    } else if (error.message.includes('expired')) {
      errorMessage = 'Access link has expired';
      statusCode = 410;
    } else if (error.message.includes('revoked')) {
      errorMessage = 'Access link has been revoked';
      statusCode = 403;
    } else if (error.message.includes('usage limit')) {
      errorMessage = 'Access link usage limit exceeded';
      statusCode = 429;
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage,
        details: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: statusCode
      }
    );
  }
}

// Stub handlers for other functions
async function handleCreateAccessLink(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleGenerateCertificate(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleSignDocument(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleGetDocumentSignatures(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleUploadDocument(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleDeleteDocument(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleSendDocument(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleSendInvite(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleAcceptInvite(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleCancelEmailChange(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleDeleteMyAccount(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleExportMyData(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleListAppCertifiers(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleListSignedCopies(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function handleRenderSignedCopy(req: Request) {
  return new Response(
    JSON.stringify({ error: 'Function not yet implemented in router' }),
    { status: 501, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
