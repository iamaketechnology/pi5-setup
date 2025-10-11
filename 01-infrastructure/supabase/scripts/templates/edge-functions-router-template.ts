// Main Router for Supabase Edge Functions (Self-Hosted)
// This "fat function" routes requests to different Edge Functions
// Date: 10 Octobre 2025

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { PDFDocument, rgb, StandardFonts } from 'https://cdn.skypack.dev/pdf-lib@^1.17.1';

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

// Rate limiting store
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(identifier: string, maxRequests = 20, windowMs = 60000): boolean {
  const now = Date.now();
  const current = rateLimitStore.get(identifier);

  if (!current || now > current.resetTime) {
    rateLimitStore.set(identifier, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (current.count >= maxRequests) {
    return false;
  }

  current.count++;
  return true;
}

// Helper to fix internal URLs to public URLs
function fixUrl(url: string | null): string | null {
  if (!url) return null;

  // Get public URL from environment or use default
  const publicUrl = Deno.env.get('PUBLIC_SUPABASE_URL') || 'http://192.168.1.74:8001';

  // Replace internal kong URL with public URL
  return url.replace('http://kong:8000', publicUrl);
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

    console.log('[verify-document] Token received:', token);
    console.log('[verify-document] Token type:', typeof token);
    console.log('[verify-document] Token length:', token?.length);

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

    console.log('[verify-document] Access link query result:', {
      found: !!accessLink,
      error: linkError?.message,
      errorDetails: linkError
    });

    if (linkError || !accessLink) {
      console.error('[verify-document] Access link not found for token:', token);
      throw new Error('Access link not found');
    }

    console.log('[verify-document] Access link found:', accessLink.id);

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
      documentUrl = fixUrl(docUrlData?.signedUrl || null);
    } catch (error) {
      console.error('Failed to create signed URL for document:', error);
    }

    if (finalCertificate.pdf_storage_key) {
      try {
        const { data: certUrlData } = await supabase.storage
          .from('certificates')
          .createSignedUrl(finalCertificate.pdf_storage_key, 3600);
        certificateUrl = fixUrl(certUrlData?.signedUrl || null);
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

// Handler: create-access-link
async function handleCreateAccessLink(req: Request) {
  console.log('[create-access-link] Handler called');

  // Rate limiting
  const authHeader = req.headers.get('authorization');
  const userId = authHeader ? 'user' : 'anonymous';

  if (!checkRateLimit(userId, 20, 60000)) {
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Rate limit exceeded. Try again later.'
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60'
        }
      }
    );
  }

  try {
    const supabase = getSupabaseClient();
    const { documentId, scope = 'view', expiresInHours = 168, maxUses } = await req.json();

    console.log('[create-access-link] Creating for document:', documentId);

    // Verify user owns the document
    const authorizationHeader = req.headers.get('Authorization');
    if (!authorizationHeader) {
      throw new Error('Authorization required');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authorizationHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      throw new Error('Invalid authorization');
    }

    // Check if user owns the document
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, owner_id')
      .eq('id', documentId)
      .eq('owner_id', user.id)
      .single();

    if (docError || !document) {
      throw new Error('Document not found or access denied');
    }

    // Generate unique token
    const token = crypto.randomUUID().replace(/-/g, '');

    // Calculate expiry date
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + expiresInHours);

    // Create access link
    const { data: accessLink, error: linkError } = await supabase
      .from('access_links')
      .insert({
        token,
        doc_id: documentId,
        scope,
        expires_at: expiresAt.toISOString(),
        max_uses: maxUses || null,
        used_count: 0
      })
      .select()
      .single();

    if (linkError) {
      console.error('[create-access-link] Error:', linkError);
      throw new Error('Failed to create access link');
    }

    console.log('[create-access-link] Created successfully');
    console.log('[create-access-link] Token:', accessLink.token);
    console.log('[create-access-link] Token length:', accessLink.token?.length);
    console.log('[create-access-link] Expires at:', accessLink.expires_at);

    return new Response(
      JSON.stringify({
        success: true,
        token: accessLink.token,
        expiresAt: accessLink.expires_at,
        scope: accessLink.scope
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    );

  } catch (error: any) {
    console.error('[create-access-link] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    );
  }
}

async function handleGenerateCertificate(req: Request) {
  console.log('[generate-certificate] Handler called');

  // Rate limiting (10 certificate generations per minute)
  const authHeader = req.headers.get('authorization');
  const userId = authHeader ? 'user' : 'anonymous';

  if (!checkRateLimit(userId, 10, 60000)) {
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Rate limit exceeded. Try again later.'
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60'
        }
      }
    );
  }

  try {
    const supabase = getSupabaseClient();
    const { documentId } = await req.json();

    console.log('Generating certificate for document:', documentId);

    // Get document details
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('*')
      .eq('id', documentId)
      .single();

    if (docError || !document) {
      throw new Error('Document not found');
    }

    // Function to normalize text for PDF encoding
    const normalizeText = (text: string): string => {
      return text
        .normalize('NFD') // Decompose accented characters
        .replace(/[\u0300-\u036f]/g, '') // Remove accent marks
        .replace(/[^\x20-\x7E]/g, '?'); // Replace non-printable ASCII with ?
    };

    // Generate certificate content
    const certificateData = {
      documentId: document.id,
      filename: normalizeText(document.filename), // Normalize filename
      sha256: document.sha256,
      fileSize: document.file_size,
      mimeType: document.mime_type,
      timestamp: new Date().toISOString(),
      certId: crypto.randomUUID(),
    };

    // Create a proper PDF certificate
    const pdfDoc = await PDFDocument.create();
    const page = pdfDoc.addPage([595, 842]); // A4 size
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
    const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

    const { width, height } = page.getSize();

    // Title
    page.drawText('CERTIFICAT DE CONFORMITÉ CERTIDOC', {
      x: 50,
      y: height - 100,
      size: 20,
      font: boldFont,
      color: rgb(0, 0, 0),
    });

    // Content
    const lines = [
      `Document ID: ${certificateData.documentId}`,
      `Nom du fichier: ${certificateData.filename}`,
      `Taille: ${certificateData.fileSize} octets`,
      `Type MIME: ${certificateData.mimeType}`,
      '',
      'Empreinte cryptographique SHA-256:',
      certificateData.sha256,
      '',
      `Horodatage de certification: ${new Date(certificateData.timestamp).toLocaleString('fr-FR')}`,
      `ID du certificat: ${certificateData.certId}`,
      '',
      'Ce document a été certifié par la plateforme CertiDoc.',
      'L\'intégrité du document peut être vérifiée en calculant',
      'son empreinte SHA-256 et en la comparant à celle ci-dessus.',
      '',
      `Généré le ${new Date().toLocaleString('fr-FR')}`
    ];

    let yPosition = height - 150;
    for (const line of lines) {
      const fontSize = line.startsWith('Empreinte') || line.length === 64 ? 10 : 12;
      const textFont = line.includes('SHA-256:') || line.includes('ID du certificat:') ? boldFont : font;

      page.drawText(line, {
        x: 50,
        y: yPosition,
        size: fontSize,
        font: textFont,
        color: rgb(0, 0, 0),
      });
      yPosition -= 20;
    }

    // Generate PDF bytes
    const pdfBytes = await pdfDoc.save();

    // Calculate certificate SHA-256
    const certHashBuffer = await crypto.subtle.digest('SHA-256', pdfBytes);
    const certHashArray = Array.from(new Uint8Array(certHashBuffer));
    const certSha256 = certHashArray.map(b => b.toString(16).padStart(2, '0')).join('');

    // Upload certificate to storage
    const certStorageKey = `certificates/${documentId}/${certificateData.certId}.pdf`;

    const { error: uploadError } = await supabase.storage
      .from('certificates')
      .upload(certStorageKey, pdfBytes, {
        contentType: 'application/pdf',
        upsert: false
      });

    if (uploadError) {
      console.error('Certificate upload error:', uploadError);
      throw new Error('Failed to upload certificate');
    }

    // Store certificate metadata
    const { data: certRecord, error: certError } = await supabase
      .from('certificates')
      .insert({
        doc_id: documentId,
        cert_sha256: certSha256,
        pdf_storage_key: certStorageKey,
        signer_key_id: 'certidoc-v1'
      })
      .select()
      .single();

    if (certError) {
      console.error('Certificate record error:', certError);
      throw new Error('Failed to store certificate record');
    }

    // Get public URL for the certificate
    const { data: urlData } = supabase.storage
      .from('certificates')
      .getPublicUrl(certStorageKey);

    console.log('Certificate generated successfully:', certRecord.id);

    return new Response(
      JSON.stringify({
        success: true,
        certificateId: certRecord.id,
        certificateUrl: fixUrl(urlData.publicUrl),
        certSha256
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    );

  } catch (error: any) {
    console.error('Error generating certificate:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    );
  }
}

async function handleSignDocument(req: Request) {
  console.log('[sign-document] Handler called');

  const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for') || 'unknown';
  if (!checkRateLimit(ip, 30, 60000)) {
    return new Response(
      JSON.stringify({ error: 'Rate limit exceeded' }),
      { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    const supabase = getSupabaseClient();
    const { docId, signerName, signerEmail, signatureBase64 } = await req.json();

    if (!docId || !signerName || !signerEmail || !signatureBase64) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get current user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify user has access to the document
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, owner_id')
      .eq('id', docId)
      .single();

    if (docError || !document) {
      return new Response(
        JSON.stringify({ error: 'Document not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if user owns the document or has sign permission
    const isOwner = document.owner_id === user.id;
    let hasSignPermission = false;

    console.log('Sign permission check:', { docId, userId: user.id, isOwner, documentOwnerId: document.owner_id });

    if (!isOwner) {
      const { data: sharedDoc, error: sharedError } = await supabase
        .from('shared_documents')
        .select('permission')
        .eq('doc_id', docId)
        .eq('user_id', user.id)
        .single();

      console.log('Shared document query result:', { sharedDoc, sharedError });
      // Only allow if the shared permission is explicitly 'sign'
      hasSignPermission = sharedDoc?.permission === 'sign';
      console.log('Has sign permission:', hasSignPermission, 'Permission:', sharedDoc?.permission);
    }

    if (!isOwner && !hasSignPermission) {
      console.log('PERMISSION DENIED - Not owner and no sign permission');
      return new Response(
        JSON.stringify({ error: 'No permission to sign this document' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if this email has already signed this document
    const { data: existingSignature } = await supabase
      .from('document_signatures')
      .select('id, signer_email, created_by')
      .eq('doc_id', docId)
      .eq('signer_email', signerEmail)
      .single();

    if (existingSignature) {
      return new Response(
        JSON.stringify({ error: 'This person has already signed this document' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Additional check: if user signs with their own email, they can only do it once
    if (signerEmail === user.email) {
      const { data: userOwnSignature } = await supabase
        .from('document_signatures')
        .select('id')
        .eq('doc_id', docId)
        .eq('created_by', user.id)
        .eq('signer_email', user.email)
        .single();

      if (userOwnSignature) {
        return new Response(
          JSON.stringify({ error: 'You have already signed this document with your own email' }),
          { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Convert base64 to blob
    const signatureData = Uint8Array.from(atob(signatureBase64), c => c.charCodeAt(0));

    // Generate unique filename
    const timestamp = new Date().toISOString();
    const filename = `signature_${docId}_${user.id}_${Date.now()}.png`;

    // Upload signature to storage
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from('signatures')
      .upload(filename, signatureData, {
        contentType: 'image/png',
        upsert: false
      });

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return new Response(
        JSON.stringify({ error: 'Failed to upload signature' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Hash IP via secure RPC (uniform)
    const clientIP = ip;
    const { data: ipHash } = await supabase.rpc('hash_ip_secure', { ip_address: clientIP });

    // Create signature record
    const { data: signature, error: signatureError } = await supabase
      .from('document_signatures')
      .insert({
        doc_id: docId,
        signer_name: signerName,
        signer_email: signerEmail,
        signature_storage_key: filename,
        created_by: user.id,
        ip_hash: ipHash || null,
        metadata: {
          user_agent: req.headers.get('user-agent'),
          timestamp: timestamp
        }
      })
      .select()
      .single();

    if (signatureError) {
      console.error('Signature record error:', signatureError);
      // Clean up uploaded file
      await supabase.storage.from('signatures').remove([filename]);

      return new Response(
        JSON.stringify({ error: 'Failed to create signature record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        signature: {
          id: signature.id,
          signer_name: signature.signer_name,
          signed_at: signature.signed_at
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('Error in sign-document function:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

async function handleGetDocumentSignatures(req: Request) {
  console.log('[get-document-signatures] Handler called');

  try {
    const supabase = getSupabaseClient();
    let docId: string | null = null;

    if (req.method === 'GET') {
      // GET method - docId in URL params
      const url = new URL(req.url);
      docId = url.searchParams.get('docId');
    } else if (req.method === 'POST') {
      // POST method - docId in body
      const body = await req.json();
      docId = body.docId;
    }

    if (!docId) {
      return new Response(
        JSON.stringify({ error: 'Document ID required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get current user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify user has access to the document
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, owner_id')
      .eq('id', docId)
      .single();

    if (docError || !document) {
      return new Response(
        JSON.stringify({ error: 'Document not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if user owns the document or has access through sharing
    const isOwner = document.owner_id === user.id;
    let hasAccess = isOwner;

    if (!isOwner) {
      const { data: sharedDoc } = await supabase
        .from('shared_documents')
        .select('permission')
        .eq('doc_id', docId)
        .eq('user_id', user.id)
        .single();

      hasAccess = !!sharedDoc;
    }

    if (!hasAccess) {
      return new Response(
        JSON.stringify({ error: 'No access to this document' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get signatures for the document
    const { data: signatures, error: signaturesError } = await supabase
      .from('document_signatures')
      .select(`
        id,
        signer_name,
        signer_email,
        signed_at,
        signature_storage_key,
        metadata
      `)
      .eq('doc_id', docId)
      .order('signed_at', { ascending: false });

    if (signaturesError) {
      console.error('Error fetching signatures:', signaturesError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch signatures' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Generate signed URLs for signature images
    const signaturesWithUrls = await Promise.all(
      signatures.map(async (signature) => {
        const { data: signedUrl } = await supabase.storage
          .from('signatures')
          .createSignedUrl(signature.signature_storage_key, 3600); // 1 hour

        return {
          ...signature,
          signature_url: fixUrl(signedUrl?.signedUrl || null)
        };
      })
    );

    return new Response(
      JSON.stringify({
        signatures: signaturesWithUrls,
        count: signatures.length
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('Error in get-document-signatures function:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

async function handleUploadDocument(req: Request) {
  console.log('[upload-document] Handler called');

  try {
    const supabase = getSupabaseClient();

    // Get user from JWT token
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { filename, mime_type, file_size, sha256, storage_key } = await req.json();

    console.log('[upload-document] Inserting document for user:', user.id);

    // Check if document with same SHA256 already exists
    const { data: existingDoc, error: checkError } = await supabase
      .from('documents')
      .select('id, filename')
      .eq('sha256', sha256)
      .eq('owner_id', user.id)
      .maybeSingle();

    if (checkError) {
      console.error('[upload-document] Check error:', checkError);
      throw checkError;
    }

    if (existingDoc) {
      return new Response(
        JSON.stringify({ error: `Document identique déjà présent: ${existingDoc.filename}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Insert document using service role (bypasses RLS)
    const { data: documentData, error: insertError } = await supabase
      .from('documents')
      .insert({
        owner_id: user.id,
        filename,
        mime_type,
        file_size,
        sha256,
        storage_key
      })
      .select()
      .single();

    if (insertError) {
      console.error('[upload-document] Insert error:', insertError);
      throw insertError;
    }

    console.log('[upload-document] Document inserted successfully:', documentData.id);

    return new Response(
      JSON.stringify({ data: documentData }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('[upload-document] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

async function handleDeleteDocument(req: Request) {
  console.log('[delete-document] Handler called');

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { documentId }: { documentId?: string } = await req.json();
    if (!documentId) throw new Error('documentId is required');

    // Fetch the document and verify ownership
    const { data: doc, error: docErr } = await supabase
      .from('documents')
      .select('id, owner_id, filename, storage_key')
      .eq('id', documentId)
      .single();
    if (docErr || !doc) throw new Error('Document not found');
    if (doc.owner_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Collect all certifiers (users who certified this document)
    const { data: certs, error: certErr } = await supabase
      .from('document_certifications')
      .select('user_id')
      .eq('doc_id', documentId);
    if (certErr) throw certErr;

    const certifierIds = Array.from(new Set((certs ?? []).map((c: { user_id: string }) => c.user_id)));

    // Fetch their emails from profiles
    let certifierEmails: string[] = [];
    if (certifierIds.length > 0) {
      const { data: profiles, error: profErr } = await supabase
        .from('profiles')
        .select('user_id, email')
        .in('user_id', certifierIds);
      if (profErr) throw profErr;
      certifierEmails = (profiles ?? [])
        .map((p: { email: string | null }) => p.email)
        .filter((e: string | null) => !!e) as string[];
    }

    // Remove owner email if present
    const ownerEmail = user.email as string | null;
    certifierEmails = certifierEmails.filter((e) => !ownerEmail || e !== ownerEmail);

    // Delete the file from storage (documents bucket)
    const delRes = await supabase.storage.from('documents').remove([doc.storage_key]);
    if (delRes.error) {
      console.error('[delete-document] Storage remove error:', delRes.error);
    }

    // Optionally delete generated certificate files
    const { data: certFiles } = await supabase
      .from('certificates')
      .select('pdf_storage_key')
      .eq('doc_id', documentId);
    if (certFiles && certFiles.length > 0) {
      const paths = certFiles.map((c: { pdf_storage_key: string }) => c.pdf_storage_key);
      const delCertRes = await supabase.storage.from('certificates').remove(paths);
      if (delCertRes.error) {
        console.error('[delete-document] Certificates remove error:', delCertRes.error);
      }
    }

    // Delete audit logs first (foreign key constraint)
    const { error: delAuditErr } = await supabase.from('audit_logs').delete().eq('doc_id', documentId);
    if (delAuditErr) {
      console.error('[delete-document] Audit logs delete error:', delAuditErr);
    }

    // Delete rows (certifications will cascade)
    const { error: delDocErr } = await supabase.from('documents').delete().eq('id', documentId);
    if (delDocErr) throw delDocErr;

    // Notify certifiers by email (OPTIONAL - only if RESEND_API_KEY exists)
    const successes: string[] = [];
    const failures: Array<{ email: string; message: string }> = [];

    if (Deno.env.get('RESEND_API_KEY') && certifierEmails.length > 0) {
      console.log('[delete-document] Sending email notifications to certifiers...');
      // Note: We cannot import Resend in the fat router, so we skip email sending
      // This would need to be handled differently or email functionality can be skipped
      console.log('[delete-document] Email sending skipped (Resend not available in fat router)');
    } else {
      console.log('[delete-document] Email notifications skipped (no RESEND_API_KEY or no certifiers)');
    }

    return new Response(
      JSON.stringify({
        success: true,
        notified: successes.length,
        requested: certifierEmails.length,
        failures,
        note: 'Email notifications are not available in fat router'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[delete-document] Error:', error);
    const message = error.message || 'Unknown error';
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleSendDocument(req: Request) {
  console.log('[send-document] Handler called');

  // Rate limiting (15 document sends per minute)
  const authHeader = req.headers.get('authorization');
  const userId = authHeader ? 'user' : 'anonymous';

  if (!checkRateLimit(userId, 15, 60000)) {
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Rate limit exceeded. Try again later.'
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60'
        }
      }
    );
  }

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { documentId, baseUrl, emails }: { documentId: string; baseUrl?: string; emails?: string[] } = await req.json();
    if (!documentId) throw new Error('documentId is required');

    // Verify ownership & fetch document
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, owner_id, filename, mime_type, file_size, storage_key')
      .eq('id', documentId)
      .eq('owner_id', user.id)
      .single();
    if (docError || !document) throw new Error('Document not found or access denied');

    // Allowed recipients: owner + all invited emails
    const ownerEmail = user.email as string | null;
    const { data: invites, error: invErr } = await supabase
      .from('email_invites')
      .select('email')
      .eq('doc_id', documentId);
    if (invErr) throw invErr;

    const allowedSet = new Set<string>();
    if (ownerEmail) allowedSet.add(ownerEmail);
    for (const row of invites || []) {
      if (row.email) allowedSet.add(row.email);
    }

    let recipients: string[];
    if (emails && emails.length > 0) {
      // Only keep emails that are allowed (owner or invited)
      recipients = emails.filter((e) => allowedSet.has(e));
    } else {
      recipients = Array.from(allowedSet);
    }

    if (recipients.length === 0) throw new Error('No valid recipients selected');

    // Create a no-expiry download link (10 years)
    const token = crypto.randomUUID().replace(/-/g, '');
    const expiresAt = new Date();
    expiresAt.setFullYear(expiresAt.getFullYear() + 10);

    const { data: link, error: linkErr } = await supabase
      .from('access_links')
      .insert({
        token,
        doc_id: documentId,
        scope: 'download',
        expires_at: expiresAt.toISOString(),
        max_uses: null,
        used_count: 0,
      })
      .select()
      .single();
    if (linkErr || !link) throw new Error('Failed to create access link');

    const origin = baseUrl || req.headers.get('origin') || 'https://' + (Deno.env.get('PROJECT_DOMAIN') || 'example.com');
    const downloadUrl = `${origin}/verify/${token}`;

    console.log('[send-document] Access link created:', downloadUrl);
    console.log('[send-document] Recipients:', recipients);

    // Email functionality is not available in fat router (no Resend import)
    if (Deno.env.get('RESEND_API_KEY')) {
      console.log('[send-document] Email sending skipped (Resend not available in fat router)');
    }

    return new Response(JSON.stringify({
      success: true,
      info: 'Email sending not available in fat router',
      recipients,
      link: downloadUrl,
      note: 'Use individual edge functions for email functionality'
    }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (error: any) {
    console.error('[send-document] Error:', error);
    return new Response(JSON.stringify({ error: error.message || 'Unknown error' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleSendInvite(req: Request) {
  console.log('[send-invite] Handler called');

  // Rate limiting (30 invites per minute)
  const authHeader = req.headers.get('authorization');
  const userId = authHeader ? 'user' : 'anonymous';

  if (!checkRateLimit(userId, 30, 60000)) {
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Rate limit exceeded. Try again later.'
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60'
        }
      }
    );
  }

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { documentId, emails, permission, message, baseUrl }: { documentId: string; emails: string[]; permission: string; message?: string; baseUrl?: string } = await req.json();

    if (!documentId || !emails || emails.length === 0) {
      throw new Error('documentId and emails are required');
    }

    if (!['view', 'download'].includes(permission)) {
      throw new Error('Invalid permission');
    }

    // Verify ownership of the document
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, owner_id, filename')
      .eq('id', documentId)
      .eq('owner_id', user.id)
      .single();

    if (docError || !document) {
      throw new Error('Document not found or access denied');
    }

    const results: Array<{ email: string; token: string }> = [];

    // Use very long expiry to simulate no expiration (10 years)
    const expiresAt = new Date();
    expiresAt.setFullYear(expiresAt.getFullYear() + 10);

    for (const email of emails) {
      const token = crypto.randomUUID().replace(/-/g, '');

      // Create access link with invited user email
      const { data: accessLink, error: linkError } = await supabase
        .from('access_links')
        .insert({
          token,
          doc_id: documentId,
          scope: permission === 'download' ? 'download' : 'view',
          expires_at: expiresAt.toISOString(),
          max_uses: null,
          used_count: 0,
          invited_user_email: email,
        })
        .select()
        .single();

      if (linkError || !accessLink) {
        console.error('[send-invite] create access link error', linkError);
        throw new Error('Failed to create access link');
      }

      // Save invite record
      const { error: inviteError } = await supabase
        .from('email_invites')
        .insert({
          doc_id: documentId,
          link_id: accessLink.id,
          email,
          message: message || null,
          permission,
          created_by: user.id,
        });

      if (inviteError) {
        console.error('[send-invite] insert invite error', inviteError);
        throw new Error('Failed to record invitation');
      }

      console.log('[send-invite] Invitation created for:', email);

      // Email sending is not available in fat router (no Resend import)
      if (Deno.env.get('RESEND_API_KEY')) {
        console.log('[send-invite] Email sending skipped (Resend not available in fat router)');
      }

      results.push({ email, token });
    }

    return new Response(JSON.stringify({
      success: true,
      invites: results,
      note: 'Email sending not available in fat router. Use individual edge functions for email functionality.'
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    console.error('[send-invite] Error:', error);
    return new Response(JSON.stringify({ error: error.message || 'Unknown error' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
}

async function handleAcceptInvite(req: Request) {
  console.log('[accept-invite] Handler called');

  try {
    const supabase = getSupabaseClient();

    // Get user from auth header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization header required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse request body
    const { token, userEmail }: { token: string; userEmail?: string } = await req.json();

    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Token is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Find the access link
    const { data: accessLink, error: linkError } = await supabase
      .from('access_links')
      .select(`
        id,
        doc_id,
        scope,
        expires_at,
        invited_user_email,
        documents (
          id,
          filename,
          owner_id
        )
      `)
      .eq('token', token)
      .is('revoked_at', null)
      .single();

    if (linkError || !accessLink) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired invitation link' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if invitation has expired
    if (new Date(accessLink.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Invitation has expired' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if the user email matches the invited email (if specified)
    if (accessLink.invited_user_email && accessLink.invited_user_email !== user.email) {
      return new Response(
        JSON.stringify({ error: 'This invitation was sent to a different email address' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create shared document entry
    const { data: sharedDoc, error: shareError } = await supabase
      .from('shared_documents')
      .insert({
        user_id: user.id,
        doc_id: accessLink.doc_id,
        shared_by: accessLink.documents.owner_id,
        permission: accessLink.scope,
        accepted_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (shareError) {
      // If already exists, update accepted_at
      if (shareError.code === '23505') { // unique constraint violation
        const { error: updateError } = await supabase
          .from('shared_documents')
          .update({ accepted_at: new Date().toISOString() })
          .eq('user_id', user.id)
          .eq('doc_id', accessLink.doc_id);

        if (updateError) {
          console.error('[accept-invite] Error updating shared document:', updateError);
          return new Response(
            JSON.stringify({ error: 'Failed to accept invitation' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      } else {
        console.error('[accept-invite] Error creating shared document:', shareError);
        return new Response(
          JSON.stringify({ error: 'Failed to accept invitation' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Update email invite if it exists
    await supabase
      .from('email_invites')
      .update({ accepted_at: new Date().toISOString() })
      .eq('link_id', accessLink.id);

    console.log('[accept-invite] Invitation accepted successfully for user:', user.id);

    return new Response(
      JSON.stringify({
        success: true,
        documentId: accessLink.doc_id,
        filename: accessLink.documents.filename,
        permission: accessLink.scope
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error: any) {
    console.error('[accept-invite] Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
}

async function handleCancelEmailChange(req: Request) {
  console.log('[cancel-email-change] Handler called');

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const supabase = getSupabaseClient();

    // Get user from token
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);

    if (userError || !user) {
      throw new Error('Invalid user token');
    }

    console.log('[cancel-email-change] Cancelling email change for user:', user.id);

    // Try direct API approach to reset email change state
    try {
      const resetResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/auth/v1/admin/users/${user.id}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json',
          'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '',
        },
        body: JSON.stringify({
          email: user.email,
          email_confirm: true,
          email_change_confirm_status: 0,
        })
      });

      const resetData = await resetResponse.json();
      console.log('[cancel-email-change] Direct reset response:', resetData);

      if (!resetResponse.ok) {
        console.error('[cancel-email-change] Direct reset error:', resetData);
      }
    } catch (resetError) {
      console.error('[cancel-email-change] Direct reset exception:', resetError);
    }

    // Also try with admin API
    const { data: adminData, error: adminError } = await supabase.auth.admin.updateUserById(user.id, {
      email_change_confirm_status: 0,
    });

    if (adminError) {
      console.error('[cancel-email-change] Admin update error:', adminError);
      throw adminError;
    }

    console.log('[cancel-email-change] Email change cancelled successfully');

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email change cancelled successfully'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error('[cancel-email-change] Error:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
}

async function handleDeleteMyAccount(req: Request) {
  console.log('[delete-my-account] Handler called');

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: authError } = await supabase.auth.getUser(token);
    if (authError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const user = userData.user;

    console.log('[delete-my-account] Deleting account for user:', user.id);

    // 1) List owned documents and related certificate files
    const { data: documents, error: docsErr } = await supabase
      .from("documents")
      .select("id, storage_key")
      .eq("owner_id", user.id);
    if (docsErr) throw docsErr;

    const docIds = (documents || []).map((d: { id: string }) => d.id);

    const { data: certs } = docIds.length
      ? await supabase
          .from("certificates")
          .select("pdf_storage_key")
          .in("doc_id", docIds)
      : { data: [] as Array<{ pdf_storage_key: string }> };

    // 2) Clean storage objects first (avoid leftovers)
    const docPaths = (documents || []).map((d: { storage_key: string }) => d.storage_key);
    if (docPaths.length) {
      try {
        await supabase.storage.from("documents").remove(docPaths);
      } catch (_) {
        console.log('[delete-my-account] Best-effort document cleanup');
      }
    }
    const certPaths = (certs || []).map((c: { pdf_storage_key: string }) => c.pdf_storage_key);
    if (certPaths.length) {
      try {
        await supabase.storage.from("certificates").remove(certPaths);
      } catch (_) {
        console.log('[delete-my-account] Best-effort certificate cleanup');
      }
    }

    // 3) Delete sharing/invites created by or linked to user (best-effort)
    await supabase.from("shared_documents").delete().eq("user_id", user.id);
    await supabase.from("shared_documents").delete().eq("shared_by", user.id);
    await supabase.from("email_invites").delete().eq("created_by", user.id);

    // 4) Delete the auth user (cascades to profiles, documents, certificates, access_links)
    const { error: delErr } = await supabase.auth.admin.deleteUser(user.id);
    if (delErr) throw delErr;

    console.log('[delete-my-account] Account deleted successfully');

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e: any) {
    console.error('[delete-my-account] Error:', e);
    const message = e.message || "Deletion failed";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

async function handleExportMyData(req: Request) {
  console.log('[export-my-data] Handler called');

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: authError } = await supabase.auth.getUser(token);
    if (authError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const user = userData.user;

    console.log('[export-my-data] Exporting data for user:', user.id);

    // Fetch profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("user_id, email, name, role, created_at, updated_at")
      .eq("user_id", user.id)
      .single();

    // Owned documents
    const { data: documents } = await supabase
      .from("documents")
      .select("id, filename, mime_type, file_size, sha256, storage_key, created_at")
      .eq("owner_id", user.id);

    const docIds = (documents || []).map((d: { id: string }) => d.id);

    // Certificates for owned documents
    const { data: certificates } = docIds.length
      ? await supabase
          .from("certificates")
          .select("id, doc_id, pdf_storage_key, cert_sha256, signer_key_id, created_at")
          .in("doc_id", docIds)
      : { data: [] as Array<{ id: string; doc_id: string; pdf_storage_key: string }> };

    // Access links for owned documents
    const { data: accessLinks } = docIds.length
      ? await supabase
          .from("access_links")
          .select("id, doc_id, token, scope, expires_at, max_uses, used_count, revoked_at, created_at, invited_user_email")
          .in("doc_id", docIds)
      : { data: [] as Array<{ id: string }> };

    // Sharing records related to the user
    const { data: sharedWithMe } = await supabase
      .from("shared_documents")
      .select("id, user_id, doc_id, shared_by, permission, accepted_at, created_at, updated_at")
      .eq("user_id", user.id);

    const { data: iShared } = await supabase
      .from("shared_documents")
      .select("id, user_id, doc_id, shared_by, permission, accepted_at, created_at, updated_at")
      .eq("shared_by", user.id);

    // Email invites created by user or addressed to user's email
    let emailInvites: Array<Record<string, unknown>> = [];
    if (profile?.email) {
      const { data: invites1 } = await supabase
        .from("email_invites")
        .select("id, doc_id, link_id, email, message, permission, created_by, created_at, accepted_at")
        .eq("email", profile.email);
      const { data: invites2 } = await supabase
        .from("email_invites")
        .select("id, doc_id, link_id, email, message, permission, created_by, created_at, accepted_at")
        .eq("created_by", user.id);
      emailInvites = [...(invites1 || []), ...(invites2 || [])];
    } else {
      const { data: invites } = await supabase
        .from("email_invites")
        .select("id, doc_id, link_id, email, message, permission, created_by, created_at, accepted_at")
        .eq("created_by", user.id);
      emailInvites = invites || [];
    }

    // Audit logs where actor is the user or document is owned by the user
    let auditLogs: Array<{ id: string } & Record<string, unknown>> = [];
    if (docIds.length) {
      const { data: logs1 } = await supabase
        .from("audit_logs")
        .select("id, actor_id, action, doc_id, link_id, ip_hash, user_agent, created_at")
        .in("doc_id", docIds);
      auditLogs = logs1 || [];
    }
    const { data: logs2 } = await supabase
      .from("audit_logs")
      .select("id, actor_id, action, doc_id, link_id, ip_hash, user_agent, created_at")
      .eq("actor_id", user.id);
    auditLogs = [...auditLogs, ...(logs2 || [])].filter(
      (v, i, a) => a.findIndex((x) => x.id === v.id) === i,
    );

    // Generate signed URLs for user-owned documents and certificates (1h)
    const storage = { documents: [] as Array<{ id: string; filename: string; url: string | null }>, certificates: [] as Array<{ id: string; doc_id: string; url: string | null }> };
    for (const d of documents || []) {
      try {
        const { data: url } = await supabase.storage
          .from("documents")
          .createSignedUrl(d.storage_key, 3600);
        storage.documents.push({ id: d.id, filename: d.filename, url: fixUrl(url?.signedUrl || null) });
      } catch {
        storage.documents.push({ id: d.id, filename: d.filename, url: null });
      }
    }
    for (const c of certificates || []) {
      try {
        const { data: url } = await supabase.storage
          .from("certificates")
          .createSignedUrl(c.pdf_storage_key, 3600);
        storage.certificates.push({ id: c.id, doc_id: c.doc_id, url: fixUrl(url?.signedUrl || null) });
      } catch {
        storage.certificates.push({ id: c.id, doc_id: c.doc_id, url: null });
      }
    }

    const exportPayload = {
      generated_at: new Date().toISOString(),
      user: { id: user.id, email: user.email, created_at: user.created_at },
      profile,
      documents,
      certificates,
      access_links: accessLinks,
      sharing: { shared_with_me: sharedWithMe || [], i_shared: iShared || [] },
      email_invites: emailInvites,
      audit_logs: auditLogs,
      storage,
    };

    console.log('[export-my-data] Export completed successfully');

    return new Response(JSON.stringify(exportPayload), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Content-Disposition": `attachment; filename=export-${user.id}.json`,
      },
    });
  } catch (e: any) {
    console.error('[export-my-data] Error:', e);
    const message = e.message || "Export failed";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

async function handleListAppCertifiers(req: Request) {
  console.log('[list-app-certifiers] Handler called');

  try {
    const supabase = getSupabaseClient();

    // Fetch all app certifications
    const { data: certs, error: certsError } = await supabase
      .from('app_certifications')
      .select('user_id, created_at')
      .order('created_at', { ascending: false });

    if (certsError) {
      throw certsError;
    }

    const userIds = Array.from(new Set((certs || []).map((c: { user_id: string }) => c.user_id)));

    let profilesMap = new Map<string, { name: string | null; email: string | null }>();
    if (userIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('user_id, name, email')
        .in('user_id', userIds);
      if (profilesError) {
        console.error('[list-app-certifiers] profilesError', profilesError);
      } else {
        profilesMap = new Map(profiles!.map((p: { user_id: string; name: string | null; email: string | null }) => [p.user_id, { name: p.name ?? null, email: p.email ?? null }]));
      }
    }

    const certifiers = (certs || []).map((c: { user_id: string; created_at: string }) => ({
      user_id: c.user_id,
      created_at: c.created_at,
      ...(profilesMap.get(c.user_id) || { name: null, email: null })
    }));

    return new Response(
      JSON.stringify({ certifiers, total: certifiers.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[list-app-certifiers] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

async function handleListSignedCopies(req: Request) {
  console.log('[list-signed-copies] Handler called');

  const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for') || 'unknown';
  if (!checkRateLimit(ip, 60, 60000)) {
    return new Response(JSON.stringify({ success: false, error: 'Rate limit exceeded' }), {
      status: 429,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Invalid authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const { docId }: { docId: string } = await req.json();
    if (!docId) {
      return new Response(JSON.stringify({ success: false, error: 'docId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Access check: owner or shared
    const { data: doc, error: docErr } = await supabase
      .from('documents')
      .select('id, owner_id')
      .eq('id', docId)
      .single();
    if (docErr || !doc) {
      return new Response(JSON.stringify({ success: false, error: 'Document not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    let hasAccess = doc.owner_id === user.id;
    if (!hasAccess) {
      const { data: shared } = await supabase
        .from('shared_documents')
        .select('permission')
        .eq('doc_id', docId)
        .eq('user_id', user.id)
        .single();
      hasAccess = !!shared;
    }
    if (!hasAccess) {
      return new Response(JSON.stringify({ success: false, error: 'No access' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // List files
    const basePath = `signed_copies/${docId}`;
    const { data: items, error: listErr } = await supabase.storage
      .from('signed_copies')
      .list(basePath, { limit: 100, sortBy: { column: 'created_at', order: 'desc' } });
    if (listErr) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to list items' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const results: Array<{ name: string; created_at?: string | null; url: string | null }> = [];
    for (const it of items || []) {
      const key = `${basePath}/${it.name}`;
      const { data: signed } = await supabase.storage
        .from('signed_copies')
        .createSignedUrl(key, 3600);
      const created = (it as unknown as { created_at?: string }).created_at || null;
      results.push({ name: key, created_at: created, url: fixUrl(signed?.signedUrl || null) });
    }

    console.log('[list-signed-copies] Found', results.length, 'signed copies');

    return new Response(JSON.stringify({ success: true, items: results }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (e: any) {
    console.error('[list-signed-copies] Error:', e);
    const message = e.message || 'Internal error';
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
}

async function handleRenderSignedCopy(req: Request) {
  console.log('[render-signed-copy] Handler called');

  const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for') || 'unknown';
  if (!checkRateLimit(ip, 20, 60000)) {
    return new Response(JSON.stringify({ success: false, error: 'Rate limit exceeded' }), {
      status: 429,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }

  try {
    const supabase = getSupabaseClient();

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Invalid authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const { docId }: { docId: string } = await req.json();
    if (!docId) {
      return new Response(JSON.stringify({ success: false, error: 'docId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Check access: owner or shared
    const { data: doc, error: docErr } = await supabase
      .from('documents')
      .select('id, owner_id, filename, storage_key, mime_type')
      .eq('id', docId)
      .single();
    if (docErr || !doc) {
      return new Response(JSON.stringify({ success: false, error: 'Document not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    let hasAccess = doc.owner_id === user.id;
    if (!hasAccess) {
      const { data: shared } = await supabase
        .from('shared_documents')
        .select('permission')
        .eq('doc_id', docId)
        .eq('user_id', user.id)
        .single();
      hasAccess = !!shared;
    }
    if (!hasAccess) {
      return new Response(JSON.stringify({ success: false, error: 'No access' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log('[render-signed-copy] Downloading PDF from storage...');

    // Fetch original PDF
    const { data: pdfFile, error: dlErr } = await supabase.storage
      .from('documents')
      .download(doc.storage_key);
    if (dlErr) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to download PDF' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    const pdfBytes = new Uint8Array(await pdfFile.arrayBuffer());
    const pdfDoc = await PDFDocument.load(pdfBytes, { updateMetadata: false });

    console.log('[render-signed-copy] Loading signature fields...');

    // Load signature fields
    const { data: fields, error: fieldsErr } = await supabase
      .from('document_signature_fields')
      .select('*')
      .eq('doc_id', docId)
      .order('field_order', { ascending: true });
    if (fieldsErr) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to load signature fields' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Load signatures
    const { data: sigs, error: sigsErr } = await supabase
      .from('document_signatures')
      .select('signer_email, signature_storage_key, signed_at')
      .eq('doc_id', docId);
    if (sigsErr) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to load signatures' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log('[render-signed-copy] Found', (fields || []).length, 'fields and', (sigs || []).length, 'signatures');

    // Build a map email->image bytes
    const imgCache = new Map<string, Uint8Array>();
    const fetchSignatureImage = async (storageKey: string): Promise<Uint8Array | null> => {
      const { data: urlData, error: su } = await supabase.storage
        .from('signatures')
        .createSignedUrl(storageKey, 300);
      if (su || !urlData?.signedUrl) return null;
      const resp = await fetch(urlData.signedUrl);
      if (!resp.ok) return null;
      const arr = new Uint8Array(await resp.arrayBuffer());
      return arr;
    };

    // Place signatures on the PDF
    let placedCount = 0;
    for (const field of (fields || [])) {
      // Find a signature for assigned email, else skip
      const sig = (sigs || []).find(s => s.signer_email && field.assigned_to_email && s.signer_email.toLowerCase() === field.assigned_to_email.toLowerCase());
      if (!sig) continue;
      if (!sig.signature_storage_key) continue;

      let imgBytes = imgCache.get(sig.signature_storage_key);
      if (!imgBytes) {
        const fetched = await fetchSignatureImage(sig.signature_storage_key);
        imgBytes = fetched || undefined;
        if (!imgBytes) continue;
        imgCache.set(sig.signature_storage_key, imgBytes);
      }

      // Embed PNG/JPG
      let embedded: any;
      try {
        embedded = await pdfDoc.embedPng(imgBytes);
      } catch (_) {
        try {
          embedded = await pdfDoc.embedJpg(imgBytes);
        } catch {
          continue;
        }
      }

      const pageIndex = Math.max(0, (field.page_number || 1) - 1);
      const page = pdfDoc.getPage(pageIndex);
      const pageHeight = page.getHeight();
      const x = Number(field.x);
      const yTop = Number(field.y);
      const w = Number(field.width);
      const h = Number(field.height);
      // Convert from top-left origin to PDF bottom-left
      const y = pageHeight - yTop - h;

      page.drawImage(embedded, { x, y, width: w, height: h, opacity: 0.95 });
      placedCount++;
    }

    console.log('[render-signed-copy] Placed', placedCount, 'signatures on PDF');

    // Add footer mark
    const firstPage = pdfDoc.getPage(0);
    const footer = `Copie signée (non-cryptographique) • ${new Date().toISOString()}`;
    firstPage.drawText(footer, { x: 36, y: 18, size: 8, color: rgb(0.4, 0.4, 0.4) });

    // Store result
    const outBytes = await pdfDoc.save({ useObjectStreams: false });
    const outBlob = new Blob([outBytes], { type: 'application/pdf' });
    const outKey = `signed_copies/${doc.id}/${crypto.randomUUID()}.pdf`;

    console.log('[render-signed-copy] Uploading signed copy to storage...');

    const { error: upErr } = await supabase.storage
      .from('signed_copies')
      .upload(outKey, outBlob, { contentType: 'application/pdf', upsert: false });
    if (upErr) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to store signed copy' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Audit with secure IP hash
    const { data: ipHash } = await supabase.rpc('hash_ip_secure', { ip_address: ip });
    await supabase.from('audit_logs').insert({
      action: 'render_signed_copy',
      doc_id: doc.id,
      ip_hash: ipHash || null,
      user_agent: req.headers.get('user-agent') || 'unknown'
    });

    // Return signed URL
    const { data: signedUrl } = await supabase.storage
      .from('signed_copies')
      .createSignedUrl(outKey, 3600);

    console.log('[render-signed-copy] Success! Signed copy created');

    return new Response(JSON.stringify({
      success: true,
      placed: placedCount,
      url: fixUrl(signedUrl?.signedUrl || null)
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (e: any) {
    console.error('[render-signed-copy] Error:', e);
    const message = e.message || 'Internal error';
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
}
